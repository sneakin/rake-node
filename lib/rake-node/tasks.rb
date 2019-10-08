require 'rake-node/tasks/copy-file'
require 'rake-node/tasks/versioning'
require 'rake-node/tasks/erb'
require 'rake-node/tasks/licenses'

module RakeNode
  module Tasks
    include CopyFile
    include Versioning
    include ERB
    include Licenses
  end
end
