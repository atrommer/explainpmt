class AcceptancetestsController < ApplicationController
  before_filter :find_acceptance, :except => [:index, :new, :create, :export, :assign]
  
  def index
    @acceptancetests = @project.acceptancetests
  end

  def new
    url = params[:story_id] ? project_story_acceptancetests_path(@project, Story.find(params[:story_id])) : project_acceptancetests_path(@project)
    common_popup(url)
  end

  def show
    render :update do |page|
      page.call 'showPopup', render(:partial => 'acceptancetests/show')
    end     
  end

  def edit
    common_popup(project_acceptancetest_path(@project, @acceptancetest))
  end

  def create
    @acceptancetest = Acceptancetest.new params[:acceptancetest]
    @acceptancetest.project = @project
    @acceptancetest.story = Story.find params[:story_id] if params[:story_id]
    render :update do |page|
      if @acceptancetest.save
        flash[:status] = "New Acceptance Test \"#{@acceptancetest.name}\" has been created."
        page.call 'location.reload'
      else
        page[:flash_notice].replace_html :inline => "<%= error_container(@acceptancetest.errors.full_messages[0]) %>"
      end
    end    
  end
  
  def update
    render :update do |page|
      if @acceptancetest.update_attributes(params[:acceptancetest])
        flash[:status] = "Acceptance Test \"#{@acceptancetest.name}\" has been updated."
        page.call 'location.reload'
      else
        page[:flash_notice].replace_html :inline => "<%= error_container(@acceptancetest.errors.full_messages[0]) %>"
      end
    end
  end
  
  def destroy
    render :update do |page|
      if @acceptancetest.destroy
        flash[:status] = "Acceptance Test \"#{@acceptancetest.name}\" has been deleted."
        page.call 'location.reload'
      end
    end
  end

  def clone_acceptance
    acceptancetest = @acceptancetest.clone
    acceptancetest.name = "Clone:" + acceptancetest.name
    acceptancetest.save
    render :update do |page|
      page.call 'location.reload'
    end 
  end
  
  def export
    headers['Content-Type'] = "application/vnd.ms-excel" 
    render :layout => false
  end

  def assign
    acceptancetests = Acceptancetest.find(params[:selected_acceptancetests] || [])
    successes, failures = [], []
    acceptancetests.each do |acceptancetest|
      acceptancetest.story = Story.find_by_id(params[:move_to])
      if acceptancetest.save
        successes << "Acceptance Tests #{acceptancetest.name} has been moved."
      else
        failures << "Acceptance Tests #{acceptancetest.name} could not be moved."
      end
    end
    flash[:status] = successes.join("\n\n") unless successes.empty?
    flash[:error] = failures.join("\n\n") unless failures.empty?
    redirect_to project_acceptancetests_path(@project)
  end

  protected
  def find_acceptance
    @acceptancetest = Acceptancetest.find params[:id]
  end
  
  def common_popup(url)
    render :update do |page|
      page.call 'showPopup', render(:partial => 'acceptancetest_form', :locals => {:url => url})
    end 
  end
  
end
