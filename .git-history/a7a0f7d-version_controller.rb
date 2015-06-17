class VersionController < ApplicationController
  def version
    @text = `cd #{Rails.root}; git rev-parse HEAD | head -1`.first(10)
  end
end
