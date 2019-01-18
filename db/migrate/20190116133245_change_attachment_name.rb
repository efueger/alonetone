class ChangeAttachmentName < ActiveRecord::Migration[5.2]
  def up
    execute("UPDATE active_storage_attachments SET name = 'audio_file' WHERE name = 'mp3'")
    execute("UPDATE active_storage_attachments SET name = 'image_file' WHERE name = 'pic'")
  end

  def down
    execute("UPDATE active_storage_attachments SET name = 'mp3' WHERE name = 'audio_file'")
    execute("UPDATE active_storage_attachments SET name = 'pic' WHERE name = 'image_file'")
  end
end
