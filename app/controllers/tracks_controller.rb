class TracksController < ApplicationController
  
  before_action :require_admin, except: [:revision, :published]
  
  def index
    @limit = 20
    @offset = params[:offset] || 0
    @count = Track.count
    # see http://www.xaprb.com/blog/2007/03/14/how-to-find-the-max-row-per-group-in-sql-without-subqueries/
    # is there a better way to do this?
    @revisions = TrackRevision.includes(track: :creator).select(:name, :created_at)
      .joins("LEFT OUTER JOIN track_revisions AS other ON track_revisions.track_id = other.track_id " +
        "AND other.id > track_revisions.id")
      .where("other.id IS NULL AND tracks.id IS NOT NULL").references(:tracks)
      .order(:track_id).limit(@limit).offset(@offset)
  end
  
  def create
    @track = @player.tracks.create
    @track.revisions.create(name: "New Track")
    redirect_to @track
  end
  
  def show
    respond_to do |format|
      format.html { @track_id = params[:id] }
      format.json { render json: track_json }
    end
  end
  
  def update
    @track = Track.find(params[:id])
    @revision = @track.revisions.last
    data = params[:data]
    data = data.read if data.respond_to?(:read) # handle upload if that's what we're given
    if @track.published_revision_id == @revision.id
      @revision = @track.revisions.create(name: params[:name], data: data)
    else
      @revision.update(name: params[:name], data: data)  
    end
    
    respond_to do |format|
      format.html { redirect_to :back }
      format.json { render plain: "Draft saved at #{@revision.updated_at}" }
    end
  end
  
  def destroy
    Track.find(params[:id]).destroy
    redirect_to :back, notice: "Track deleted."
  end
  
  def publish
    @track = Track.find(params[:id])
    @revision = @track.revisions.last
    if @track.published_revision_id == @revision.id
      @revision = @track.revisions.create(name: params[:name], data: params[:data])
    else
      @revision.update(name: params[:name], data: params[:data]) 
    end
    @track.update(published_revision_id: @revision.id)
    @track.revisions.where.not(id: @revision.id).each do |revision|
      revision.disconnect
    end
    render plain: "Published at #{@revision.updated_at}"
  end
  
  def unpublish
    @track = Track.find(params[:id])
    @track.update(published_revision_id: nil)
    @revision = @track.revisions.last
    @track.revisions.where.not(id: @revision.id).each do |revision|
      revision.disconnect
    end
    redirect_to :back, notice: "Track unpublished."
  end
  
  def export
    render body: params[:data], content_type: "application/binary"
  end
  
  def revision
    @revision = TrackRevision.find(params[:id])
    @track = @revision.track
    render json: revision_json
  end
  
  def published
    tracks = []
    Track.includes(:published_revision).where.not(published_revision_id: nil).order(:id).each do |track|
      tracks.push({ name: track.published_revision.name, id: track.published_revision.id })
    end
    render json: tracks
  end
  
  private
    def track_json
      @track = Track.find(params[:id])
      @revision = @track.revisions.last
      revision_json
    end
    
    def revision_json
      json = { status: "#{@track && @track.published_revision_id == @revision.id ? 'Published' : 'Draft saved'} " +
        "at #{@revision.updated_at}" }
      json[:name] = @revision.name
      json[:publishedRevision] = @track ? @track.published_revision_id : 0
      json[:data] = @revision.data
      json
    end
end
