task :default => :spec

task :spec do
  sh "spec ./lib/active_record_extensions_spec.rb"
end

task :doc do
  sh "erb README.md.erb > README.md"
end