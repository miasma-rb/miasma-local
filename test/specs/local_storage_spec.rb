require 'tmpdir'
require 'fileutils'
require 'miasma/contrib/local'

describe Miasma::Models::Storage::Local do

  before do
    @directory = Dir.mktmpdir
    @storage = Miasma.api(
      :type => :storage,
      :provider => :local,
      :credentials => {
        :object_store_root => @directory
      }
    )
  end

  after do
    FileUtils.rm_rf(@directory)
  end

  let(:storage){ @storage }
  let(:cassette_prefix){ 'local' }

  instance_exec(&MIASMA_STORAGE_ABSTRACT)

end
