module Helpers
  def shell! str # danger -- will execute any arbitrary string
    Marshal.load %x{ruby #{File.dirname(__FILE__)}/argv.rb #{str}}
  end
end
