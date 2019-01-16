# frozen_string_literal: true

class ConvertToActiveStorage < ActiveRecord::Migration[5.2]
  require 'open-uri'

  def up
    get_blob_id = 'LAST_INSERT_ID()'

    active_storage_blob_statement = ActiveRecord::Base.connection.raw_connection.prepare(<<-SQL)
      INSERT INTO active_storage_blobs (
        `key`, filename, content_type, metadata, byte_size, checksum, created_at
      ) VALUES (?, ?, ?, '{}', ?, ?, ?)
    SQL

    active_storage_attachment_statement = ActiveRecord::Base.connection.raw_connection.prepare(<<-SQL)
      INSERT INTO active_storage_attachments (
        name, record_type, record_id, blob_id, created_at
      ) VALUES (?, ?, ?, #{get_blob_id}, ?)
    SQL

    Rails.application.eager_load!
    models = ActiveRecord::Base.descendants.reject(&:abstract_class?)

    transaction do
      models.each do |model|
        attachments = model.column_names.map do |c|
          if c =~ /(.+)_file_name$/
            $1
          end
        end.compact

        if attachments.blank?
          next
        end

        model.find_each.each do |instance|
          attachments.each do |attachment_name|
            attachment = instance.send(attachment_name)
            if attachment.path.blank?
              next
            end

            active_storage_blob_statement.execute(
              key(instance, attachment, attachment_name),
              instance.send("#{attachment_name}_file_name"),
              instance.send("#{attachment_name}_content_type"),
              instance.send("#{attachment_name}_file_size"),
              checksum(attachment),
              instance.updated_at.to_s(:db)
            )

            active_storage_attachment_statement.execute(
              attachment_name,
              model.name,
              instance.id,
              instance.updated_at.to_s(:db)
            )
          end
        end
      end
    end
  end

  def down
    execute("SET FOREIGN_KEY_CHECKS = 0")
    execute("TRUNCATE active_storage_blobs")
    execute("TRUNCATE active_storage_attachments")
  ensure
    execute("SET FOREIGN_KEY_CHECKS = 1")
  end

  private

  def key(instance, attachment, attachment_name)
    # Keep using the path as the key for previously uploaded files.
    attachment.path[1..]
  end

  def checksum(attachment)
    url = attachment.url
    if url.start_with?('http')
      # Unfortunately we need to download the entire object to compute its MD5.
      Digest::MD5.base64digest(Net::HTTP.get(URI(attachment.url)))
    else
      Digest::MD5.file(Rails.root.join('public' + url)).base64digest
    end
  end
end
