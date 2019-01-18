# frozen_string_literal: true

class Upload
  class Metadata
    ATTRIBUTE_TO_ID3_TAG_NAME = {
      album: 'album',
      artist: 'artist',
      bitrate: 'bitrate',
      length: 'length',
      samplerate: 'samplerate',
      title: 'title',
      id3_track_num: 'tracknum',
      genre: 'genre_s'
    }.freeze

    attr_reader :file

    def initialize(file)
      @file = file
    end

    def attributes
      @attributes ||= extract_attributes
    end

    def self.sanitize_encoding(value)
      if value.respond_to?(:encode)
        value.encode(
          'UTF-8', invalid: :replace, undef: :replace, replace: "\ufffd"
        ).mb_chars.normalize.to_s
      else
        value
      end
    end

    private

    def extract_attributes
      Mp3Info.open(file.path) do |info|
        ATTRIBUTE_TO_ID3_TAG_NAME.each_with_object({}) do |(name, tag_name), attributes|
          value = info.respond_to?(tag_name) ? info.public_send(tag_name) : info.tag[tag_name]
          attributes[name] = self.class.sanitize_encoding(value)
        end.compact
      end
    rescue Mp3InfoError
      {}
    end
  end
end
