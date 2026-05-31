class RidePostsController < ApplicationController
  before_action :set_ride_post, only: %i[ show edit update destroy ]

  # GET /ride_posts or /ride_posts.json
  def index
    @ride_posts = RidePost.all
  end

  # GET /ride_posts/1 or /ride_posts/1.json
  def show
  end

  # GET /ride_posts/new
  def new
    @ride_post = RidePost.new
  end

  # GET /ride_posts/1/edit
  def edit
  end

  # POST /ride_posts or /ride_posts.json
  def create
    @ride_post = RidePost.new(ride_post_params)

    respond_to do |format|
      if @ride_post.save
        format.html { redirect_to @ride_post, notice: "Ride post was successfully created." }
        format.json { render :show, status: :created, location: @ride_post }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @ride_post.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /ride_posts/1 or /ride_posts/1.json
  def update
    respond_to do |format|
      if @ride_post.update(ride_post_params)
        format.html { redirect_to @ride_post, notice: "Ride post was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @ride_post }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @ride_post.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /ride_posts/1 or /ride_posts/1.json
  def destroy
    @ride_post.destroy!

    respond_to do |format|
      format.html { redirect_to ride_posts_path, notice: "Ride post was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_ride_post
      @ride_post = RidePost.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def ride_post_params
      params.fetch(:ride_post, {})
    end
end
