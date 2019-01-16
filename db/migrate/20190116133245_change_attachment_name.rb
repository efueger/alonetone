class ChangeAttachmentName < ActiveRecord::Migration[5.2]
  def up
    execute("UPDATE active_storage_attachments SET name = 'original' WHERE name = 'mp3'")
    execute("UPDATE active_storage_attachments SET name = 'image' WHERE name = 'pic'")
  end

  def down
    execute("UPDATE active_storage_attachments SET name = 'mp3' WHERE name = 'original'")
    execute("UPDATE active_storage_attachments SET name = 'pic' WHERE name = 'image'")
  end
end
