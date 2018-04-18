
require "digest/md5"
require "json"
require "zip/zip"
require "tempfile"
require 'rest_client'

class TheHoldUploader

  def self.build_manifest(folder_path)
    pwd = Dir.pwd

    Dir.chdir( folder_path )

    manifest = {}
    Dir.glob(File.join("**", "*")) do | filename |
      next if File.directory?(filename)
      begin
      md5sum = Digest::MD5.hexdigest( File.read(filename))
      manifest[filename]= md5sum
      rescue => e
        App.alert(filename)
        App.alert(e.inspect)
      end
    end

    open("manifest.json", "wb"){|f| f.write( JSON.dump(manifest) )}

    Dir.chdir(pwd)
  end



  def self.upload_patch(to_folder, options)

    begin
      uri = URI(options[:host])
      puts "#{uri.scheme}://#{options[:project]}.#{options[:login]}.#{uri.host}/manifest.json"
      form = JSON.load( open("#{uri.scheme}://#{options[:project]}.#{options[:login]}.#{uri.host}/manifest.json",'r'){|f| f.read} )
    rescue
      form = {}
    end
    self.build_manifest(to_folder)

    to_json_file = File.join(to_folder, 'manifest.json')
    to_json_data = open(to_json_file,'r'){|f| f.read}
    to = JSON.load( to_json_data )

    tempfile = File.join( Dir.tmpdir,"the-hold-#{options[:project]}-#{rand}.zip")

    # Call java.util.zip directly.
    abs_path = File.absolute_path(to_folder)
    puts "Creating zipped file: #{tempfile}"
    fo = java.io::FileOutputStream.new(tempfile)
    zo = java.util.zip.ZipOutputStream.new(fo)

    puts "=> Writing manifest.json"
    zo.putNextEntry(java.util.zip.ZipEntry.new("manifest.json"))
    fi = java.io::FileInputStream.new(File.join(abs_path, 'manifest.json'))
    c = 0
    while((c=fi.read())!=-1) do
      zo.write(c)
    end
    zo.closeEntry

    to.each do |filename, md5|
      if form[filename] != md5
        puts "=> Writing #{filename}"
        zo.putNextEntry( java.util.zip.ZipEntry.new(filename) )
        fi = java.io::FileInputStream.new( File.join(abs_path, filename) )
        c = 0
        while((c=fi.read())!=-1) do
          zo.write(c)
        end
        zo.closeEntry
      else
        puts "-  Skipping #{filename}"
      end
    end

    zo.close
    fo.close

    #Zip::ZipOutputStream.open(tempfile) do |zos|
      #zos.put_next_entry 'manifest.json'
      #zos.puts to_json_data

      #to.each do |filename, md5|
        #puts filename
        #if form[filename] != md5
          #zos.put_next_entry filename
          #zos.puts open( File.join(to_folder, filename), 'r'){|f| f.read}
        #end
      #end
    #end
    f = File.new(tempfile, "rb")
    f.instance_eval "def content_type; 'application/zip'; end"
    f.instance_eval "def original_filename; 'patch_file.zip'; end"

    respone= RestClient.post( "#{options[:host]}/upload" , {
      "patch_file" => f,
      "login"      => options[:login],
      "token"      => options[:token],
      "project"    => options[:project],
      "cname"      => options[:cname],
      "project_site_password"    => options[:project_site_password]
    })

    File.unlink(tempfile)
    puts respone.inspect
    respone.body
  end

end
