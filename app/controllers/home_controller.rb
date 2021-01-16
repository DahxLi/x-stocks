# frozen_string_literal: true

# Controller to provide home page information
class HomeController < ApplicationController
  def index
    @page_title = 'Home'
    @page_menu_item = :home
    @fear_n_greed_image_url = Etl::Refresh::FearNGreed.new.image_url
  end
end
