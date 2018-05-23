class PromptsController < ApplicationController
  
  skip_before_action :require_login, only: [:show]
  after_action :allow_iframe, only: [:show]
  
  def show
    render html: Prompt.find(params[:id]).content.html_safe
  end
  
  private
  
    def allow_iframe
      response.headers.except! 'X-Frame-Options'
    end
end
