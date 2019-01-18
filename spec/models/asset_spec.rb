# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Asset, type: :model do
  it "supports characters outside of the basic multilingual plane in the title" do
    expect(Asset.new(title: '👍').title).to eq('👍')
  end

  context "asset with audio file" do
    let(:asset) { assets(:will_studd_rockfort_combalou) }

    context "operating with Disk storage" do
      it "does not generate a public URL because that's an S3 thing" do
        expect(asset.public_url).to be_nil
      end

      it "generates a presigned URL for accessing the file" do
        url = asset.presigned_url
        expect(url).to start_with('https')
        expect(url).to include(asset.audio_file.key)
        expect(url).to include('X-Amz-Signature')
      end
    end

    context "operating with S3 storage" do
      around do |example|
        with_storage_service('s3') do
          example.run
        end
      end

      it "generates a public URL which is not signed for access" do
        url = asset.public_url
        expect(url).to start_with('https')
        expect(url).to include(asset.audio_file.key)
        expect(url.split('?').length).to be(1)
      end

      it "generates a presigned URL for accessing the file" do
        url = asset.presigned_url
        expect(url).to start_with('https')
        expect(url).to include(asset.audio_file.key)
        expect(url).to include('X-Amz-Signature')
      end
    end
  end

  context "validation" do
    let(:mp3_asset) do
      Asset.new(
        user: users(:will_studd),
        audio_file: file_fixture_uploaded_file(
          'smallest.mp3', filename: 'smallest.mp3', content_type: 'audio/mpeg'
        )
      )
    end
    let(:zip_asset) do
      Asset.new(
        user: users(:will_studd),
        audio_file: file_fixture_uploaded_file(
          'smallest.zip', filename: 'smallest.zip', content_type: 'application/zip'
        )
      )
    end
    let(:binary_asset) do
      Asset.new(
        user: users(:will_studd),
        audio_file: file_fixture_uploaded_file(
          'smallest.zip', filename: 'smallest.zip', content_type: 'application/octet-stream'
        )
      )
    end
    let(:huge_asset) do
      Asset.new(
        user: users(:will_studd),
        audio_file: file_fixture_uploaded_file(
          'smallest.mp3', filename: 'smallest.mp3', content_type: 'audio/mpeg'
        )
      )
    end

    it "can be an mp3 file" do
      expect(mp3_asset).to be_valid
    end

    it "cannot be a zip file" do
      expect(zip_asset).not_to be_valid
      expect(zip_asset.errors[:audio_file]).to_not be_empty
    end

    it "cannot be an unknown file" do
      expect(binary_asset).not_to be_valid
      expect(binary_asset.errors[:audio_file]).to_not be_empty
    end

    it "cannot be larger than 60 megabytes" do
      huge_asset.audio_file.byte_size = 230.megabytes
      expect(huge_asset).not_to be_valid
      expect(huge_asset.errors[:audio_file]).to_not be_empty
    end
  end

  context "mp3 tags" do
    it "should use tag2 TT2 as name if present" do
      asset = file_fixture_asset('muppets.mp3', content_type: 'audio/mpeg')
      expect(asset.name).to eq('Old Muppet Men Booing')
    end

    it "should still work even when tags are empty and the name is weird" do
      asset = file_fixture_asset('_ .mp3', content_type: 'audio/mpeg')
      expect(asset.permalink).to eq('untitled')
      expect(asset.name).to eq('untitled')
    end

    it "should handle strange charsets / characters in title tags" do
      asset = file_fixture_asset('japanese-characters.mp3', content_type: 'audio/mpeg')
      expect(asset.name).to eq('01-¶ÔμÄÈË') # name is still 01-\266Ե??\313"
      expect(asset.mp3_file_name).to eq('japanese-characters.mp3')
    end

    it "should handle empty name in mp3 tag" do
      asset = file_fixture_asset('japanese-characters.mp3', content_type: 'audio/mpeg')
      expect(asset.permalink).to eq("01-oaee") # name is 01-\266Ե??\313"
      asset.title = 'bee'
      asset.save
      expect(asset.permalink).to eq('bee')
    end

    it "should cope with non-english filenames" do
      asset = file_fixture_asset('中文測試.mp3', content_type: 'audio/mpeg')
      expect(asset.save).to eq(true)
      asset.mp3_file_name == '中文測試.mp3'
    end

    it "should handle umlauts and non english characters in the filename" do
      filename = 'müppets.mp3'.mb_chars.normalize
      asset = file_fixture_asset(
        'muppets.mp3',
        filename: filename,
        content_type: 'audio/mpeg'
      )
      expect(asset.mp3_file_name).to eq(filename)
    end

    it "should handle permalink with ???? as tags, default to untitled" do
      asset = file_fixture_asset('中文測試.mp3', content_type: 'audio/mpeg')
      expect(asset).to be_persisted
      expect(asset.name).to eq("中文測試")
      expect(asset.permalink).not_to be_blank
      expect(asset.permalink).to eq("untitled")
    end

    it "should use the mp3 tag1 title as name if present" do
      asset = file_fixture_asset('tag1.mp3', content_type: 'audio/mpeg')
      expect(asset.name).to eq("Mark S Williams")
    end

    it "should use the filename as name if no tags are present" do
      asset = file_fixture_asset('titleless.mp3', content_type: 'audio/mpeg')
      expect(asset.name).to eq('Titleless')
    end

    it "should generate a permalink from tags" do
      asset = file_fixture_asset('tag2.mp3', content_type: 'audio/mpeg')
      expect(asset.permalink).to eq('put-a-nickel-on-my-door')
    end

    it "should generate unique permalinks" do
      asset = file_fixture_asset('tag2.mp3', content_type: 'audio/mpeg')
      asset2 = file_fixture_asset('tag2.mp3', content_type: 'audio/mpeg')
      expect(asset2.permalink).to eq('put-a-nickel-on-my-door-1')
    end

    it "should make sure to grab bitrate and length in seconds" do
      asset = file_fixture_asset('muppets.mp3', content_type: 'audio/mpeg')
      expect(asset.bitrate).to eq(192)
      expect(asset.length).to eq('0:13')
    end

    describe "#publish" do
      it "should update private false to true" do
        asset = assets(:private_track)
        asset.publish!
        asset.reload
        expect(asset.private).to eq(false)
      end
    end
  end

  context "on update" do
    it "should regenerate a permalink after the title is changed" do
      asset = file_fixture_asset('muppets.mp3', content_type: 'audio/mpeg')
      asset.title = 'New Muppets 123'
      asset.save
      expect(asset.permalink).to eq('new-muppets-123')
    end
  end
end
