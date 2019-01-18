# frozen_string_literal: true

# An asset represents an audio track.
class Asset < ApplicationRecord
  concerned_with :radio, :statistics, :greenfield
  attribute :user_agent, :string

  scope :published,       -> { where(private: false, is_spam: false) }
  scope :not_spam,        -> { where(is_spam: false) }
  scope :recent,          -> { order('assets.id DESC').includes(:user) }
  scope :last_updated,    -> { order('updated_at DESC').first }
  scope :descriptionless, -> { where('description = "" OR description IS NULL').order('created_at DESC').limit(10) }
  scope :random_order,    -> { order("RAND()") }
  scope :favorited,       -> { select('distinct assets.*').includes(:tracks).where('tracks.is_favorite = (?)', true).order('tracks.id DESC') }
  scope :not_current,     ->(id) { where('id != ?', id) }
  scope :for_user,        ->(user_id) { where(user_id: user_id) }
  scope :hottest,         -> { where('hotness > 0').order('hotness DESC') }
  scope :most_commented,  -> { where('comments_count > 0').order('comments_count DESC') }
  scope :most_listened,   -> { where('listens_count > 0').order('listens_count DESC') }

  belongs_to :user, counter_cache: true
  has_one  :audio_feature
  has_many :tracks,    dependent: :destroy
  has_many :playlists, through: :tracks
  has_many :listens,   -> { order('listens.created_at DESC') }, dependent: :destroy
  has_many :comments, as: :commentable, dependent: :destroy

  has_many :listeners,
    -> { distinct.order('listens.created_at DESC') },
    through: :listens

  has_many :favoriters,
    -> { where('tracks.is_favorite' => true).order('tracks.created_at DESC') },
    source: :user,
    through: :tracks

  has_one_attached :audio_file

  has_permalink :name, true
  after_create :notify_followers, if: :published?
  after_commit :create_waveform, on: :create

  include Rakismet::Model
  rakismet_attrs  author: proc { user.display_name },
                  author_email: proc { user.email },
                  content: proc { description },
                  permalink: proc { full_permalink },
                  user_role: proc { role },
                  comment_type: 'mp3-post' # this can't be "mp3", it calls paperclip

  validates :user, presence: true
  validates :audio_file, attached: {
    content_type: %w[audio/mpeg audio/mp3 audio/x-mp3],
    byte_size: { less_than: 60.megabytes }
  }

  # @deprecated Please use asset.audio_file.filename.
  def mp3_file_name
    if filename = audio_file&.filename
      filename.to_s
    end
  end

  # @deprecated Please use asset.audio_file.byte_size.
  def mp3_file_size
    audio_file&.byte_size
  end

  # @deprecated Please use asset.audio_file.content_type.
  def mp3_content_type
    audio_file&.content_type
  end

  # Returns a name for the asset based on its title or filename.
  def name
    return title.strip if title.present?

    name = File.basename(mp3_file_name.to_s, '.*').humanize
    name.blank? ? 'untitled' : name
  end

  # Generate permalink for the instance if the permalink is blank or when the title changed.
  def generate_permalink
    return if permalink.present? && !title_changed?

    self.permalink = fix_duplication(normalize(name)).presence || 'untitled'
  end

  # Returns a URL to the object on remote storage or nil when the file is stored on disk.
  def public_url
    return nil unless audio_file
    return nil unless audio_file.service.respond_to?(:bucket)

    audio_file.service.bucket.object(audio_file.key).public_url
  end

  # Returns a presigned URL which gives temporary access to the file.
  def presigned_url
    audio_file&.service_url
  end

  def self.latest(limit = 10)
    includes(user: :pic).limit(limit).order('assets.id DESC')
  end

  def self.id_not_in(asset_ids)
    if asset_ids.present?
      where("assets.id NOT IN (?)", asset_ids)
    else
      all
    end
  end

  def self.user_id_in(user_ids)
    where("assets.user_id IN (?)", user_ids)
  end

  def self.conditions_by_like(value)
    conditions = ['assets.title', 'assets.description', 'assets.mp3_file_name'].collect do |c|
      "#{c} LIKE " + ActiveRecord::Base.connection.quote("%#{value}%")
    end
    where(conditions.join(" OR "))
  end

  # needed for views in case we've got multiple assets on the same page
  # TODO: this is a view concern, move to helper, or better yet, deal w/it in .js
  def unique_id
    object_id
  end

  def first_playlist
      Track.where(asset_id: id).first.playlists.first
  rescue StandardError
      nil
  end

  # Helper for rakismet
  def user_ip
    user.current_login_ip
  end

  # allows classes outside Asset to use the same format
  def self.formatted_time(time)
    if time
      min_and_sec = time.divmod(60)
      minutes = min_and_sec[0].to_i.to_s
      seconds = min_and_sec[1].to_i.to_s
      seconds = "0" + seconds if seconds.length == 1
      minutes + ':' + seconds
    else
      "?:??"
    end
  end

  def length
    self.class.formatted_time(self[:length])
  end

  def seconds
    self[:length] # a bit backwards, ain't it?
  end

  def guest_can_comment?
    if user.settings.present? && user.settings['block_guest_comments'].present?
      user.settings['block_guest_comments'] == "false"
    else
      true
    end
  end

  def published?
    !private?
  end

  def publish!
    update(private: false) && notify_followers if private?
  end

  # needed for spam detection
  def full_permalink
    "https://#{hostname}/#{user.login}/tracks/#{permalink}"
  end

  def to_param
    permalink
  end

  def notify_followers
    user.followers.select(&:wants_email?).each do |user|
      AssetNotificationJob.set(wait: 10.minutes).perform_later(id, user.id)
    end
  end

  def create_waveform
    Greenfield::WaveformExtractJob.perform_later(id)
  end

  def role
    if user.moderator?
      'admin'
    else
      'user'
    end
  end
end

# == Schema Information
#
# Table name: assets
#
#  id               :integer          not null, primary key
#  album            :string(255)
#  artist           :string(255)
#  bitrate          :integer
#  comments_count   :integer          default(0)
#  credits          :text(4294967295)
#  description      :text(4294967295)
#  description_html :text(4294967295)
#  favorites_count  :integer          default(0)
#  genre            :string(255)
#  hotness          :float(24)
#  id3_track_num    :integer          default(1)
#  is_spam          :boolean          default(FALSE)
#  length           :integer
#  listens_count    :integer          default(0)
#  listens_per_week :float(24)
#  lyrics           :text(4294967295)
#  mp3_content_type :string(255)
#  mp3_file_name    :string(255)
#  mp3_file_size    :integer
#  permalink        :string(255)
#  private          :boolean          default(FALSE), not null
#  samplerate       :integer
#  thumbnails_count :integer          default(0)
#  title            :string(255)
#  waveform         :text(4294967295)
#  youtube_embed    :string(255)
#  created_at       :datetime
#  updated_at       :datetime
#  user_id          :integer
#
# Indexes
#
#  index_assets_on_hotness                      (hotness)
#  index_assets_on_permalink                    (permalink)
#  index_assets_on_updated_at                   (updated_at)
#  index_assets_on_user_id                      (user_id)
#  index_assets_on_user_id_and_listens_per_day  (user_id,listens_per_week)
#
