module Greenfield
  class PlaylistDownload < ActiveRecord::Base
    MAX_SIZE     = 2000.megabytes
    CONTENT_TYPE = ['application/zip', 'application/gzip'].freeze

    belongs_to :playlist
  end
end
