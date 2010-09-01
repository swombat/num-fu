require 'ftools'

module NumFu
  @@tempfile_path           = File.join(RAILS_ROOT, 'tmp', 'attachment_fu')
  @@use_nginx_upload_module = false
  mattr_writer                :tempfile_path,
                              :use_nginx_upload_module
  module ActMethods
    def has_attachment(options = {})
      options[:min_size]         ||= 1
      options[:max_size]         ||= 2.gigabytes
      
      extend ClassMethods unless (class << self; included_modules; end).include?(ClassMethods)
      include InstanceMethods unless included_modules.include?(InstanceMethods)

      self.attachment_options = options      
    end
  end
  
  module ClassMethods
    # Performs common validations for attachment models.
    def validates_as_attachment
      validates_presence_of :size, :content_type, :filename, :original_filename
    end
    
    def self.extended(base)
      base.class_inheritable_accessor :attachment_options
      base.before_validation :set_size
      base.after_save :save_to_storage
      # base.after_destroy :destroy_file
    end
  end
  
  module InstanceMethods
    def uploaded_data=(file_data)
      return nil if file_data.nil? || file_data.size == 0 
      
      self.content_type           = file_data.content_type
      self.original_filename      = file_data.original_filename
      prefix                      = "#{Digest::MD5.hexdigest(Time.now.to_s + rand(99999).to_s)[0..15]}"
      self.filename               = sanitize_filename("#{prefix}-#{file_data.original_filename}")
      if file_data.is_a?(StringIO)
        file_data.rewind
        @temp_path = write_to_temp_file data unless data.nil?
      else
        @temp_path = file_data.path
      end
    end

    # Writes the given file to a randomly named Tempfile.
    def write_to_temp_file(data)
      self.class.write_to_temp_file data, random_tempfile_filename
    end

    def save_to_storage
      if @temp_path && File.file?(@temp_path)
        FileUtils.mkdir_p(File.dirname(full_filename))
        File.mv(@temp_path, full_filename)
        File.chmod(attachment_options[:chmod] || 0666, File.expand_path(full_filename))
      end
    rescue ::Exception => e
      RAILS_DEFAULT_LOGGER.debug "Failed to chmod #{full_filename} - #{e.inspect}"
    end
    
    def delete
      self.update_attribute(:deleted_at, Time.now)
    end
    
    def delete_file
      File.delete(self.full_filename) if File.exists?(self.full_filename)
    end

    def full_filename
      file_system_path = self.attachment_options[:path_prefix].to_s
      File.expand_path(File.join(RAILS_ROOT, file_system_path, *partitioned_path(filename)))
    end
    
  protected
    def sanitize_filename(filename)
      returning filename.strip do |name|
        # NOTE: File.basename doesn't work right with Windows paths on Unix
        # get only the filename, not the whole path
        name.gsub! /^.*(\\|\/)/, ''

        # Finally, replace all non alphanumeric, underscore or periods with underscore
        name.gsub! /[^\w\.\-]/, '_'
      end
    end
    
    def random_tempfile_filename
      "#{rand Time.now.to_i}#{filename || 'attachment'}"
    end

    def partitioned_path(*args)
      ("%08d" % (id >> 8)).scan(/..../) + args
    end

    def write_to_temp_file(data, temp_base_name)
      returning Tempfile.new(temp_base_name, NumFu.tempfile_path) do |tmp|
        tmp.binmode
        tmp.write data
        tmp.close
      end
    end
    
    def set_size
      if @temp_path && File.exists?(@temp_path)
        self.size = File.size(@temp_path)
      elsif self.id && File.exists?(self.full_filename)
        self.size = File.size(self.full_filename)
      end
    end
  end
  
  class FakeUploadData
    attr_accessor :filename, :content_type, :path, :original_filename, :size
  end
  
end