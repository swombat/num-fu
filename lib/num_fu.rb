module NumFu
  
  module ActMethods
    def has_attachment(options = {})
      options[:min_size]         ||= 1
      options[:max_size]         ||= 2.gigabytes
      
      self.attachment_options = options
      
      extend ClassMethods unless (class << self; included_modules; end).include?(ClassMethods)
      include InstanceMethods unless included_modules.include?(InstanceMethods)
    end
  end
  
  module ClassMethods
    # Performs common validations for attachment models.
    def validates_as_attachment
      validates_presence_of :size, :content_type, :filename, :original_filename
      validate              :attachment_attributes_valid?
    end
    
    def self.extended(base)
      base.class_inheritable_accessor :attachment_options
      base.before_validation :set_size_from_temp_path
      base.after_save :save_to_storage
      # base.after_destroy :destroy_file
      base.after_validation :process_attachment
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
      if File.file?(@temp_path)
        FileUtils.mkdir_p(File.dirname(full_filename))
        File.cp(temp_path, full_filename)
        File.chmod(attachment_options[:chmod] || 0744, full_filename)
      end
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

    def full_filename
      file_system_path = self.attachment_options[:path_prefix].to_s
      File.join(RAILS_ROOT, file_system_path, *partitioned_path(filename))
    end
  end
end