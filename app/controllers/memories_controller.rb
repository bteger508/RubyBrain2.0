class MemoriesController < ApplicationController
  before_action :set_memory, only: %i[ show edit update destroy ]

  # GET /memories or /memories.json
  def index
    @memories = Memory.all
  end

  # GET /memories/1 or /memories/1.json
  def show
  end

  # GET /memories/new
  def new
    @memory = Memory.new
  end

  # GET /memories/1/edit
  def edit
  end

  # POST /memories or /memories.json
  def create
    @memory = Memory.new(memory_params)

    respond_to do |format|
      if @memory.save
        format.html { redirect_to @memory, notice: "Memory was successfully created." }
        format.json { render :show, status: :created, location: @memory }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @memory.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /memories/1 or /memories/1.json
  def update
    respond_to do |format|
      if @memory.update(memory_params)
        format.html { redirect_to @memory, notice: "Memory was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @memory }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @memory.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /memories/1 or /memories/1.json
  def destroy
    @memory.destroy!

    respond_to do |format|
      format.html { redirect_to memories_path, notice: "Memory was successfully destroyed.", status: :see_other }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_memory
      @memory = Memory.find(params.expect(:id))
    end

    # Only allow a list of trusted parameters through.
    def memory_params
      params.expect(memory: [ :title, :description, :superseded_by_id, :forgotten, :last_recalled_at, :recall_count ])
    end
end
