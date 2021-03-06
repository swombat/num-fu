module NumFu
  module UploadExtractor
    
    # Determine whether the upload is via Nginx Upload Module or not, and if so, transmogrify it to be
    # in a standard form that can be passed on to InstanceMethods#uploaded_data=
    def extract_upload(name="file")
      if params["#{name}"] && params["#{name}"]["uploaded_data"] && params["#{name}"]["uploaded_data"][".path"]
        fake_upload_data = FakeUploadData.new
        fake_upload_data.path = params["#{name}"]["uploaded_data"][".path"]
        fake_upload_data.original_filename = params["#{name}"]["uploaded_data"][".name"]
        fake_upload_data.content_type = params["#{name}"]["uploaded_data"][".content_type"]
        fake_upload_data.size = File.size(fake_upload_data.path)
        params["#{name}"]["uploaded_data"] = fake_upload_data
      end
    rescue ::NoMethodError
      # nothing
    end
    
  end
end