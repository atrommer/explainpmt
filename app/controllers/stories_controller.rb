##############################################################################
# eXPlain Project Management Tool
# Copyright (C) 2005  John Wilger <johnwilger@gmail.com>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
##############################################################################


class StoriesController < ApplicationController
  before_filter :require_current_project

  # Lists all of the stories in the project 'Backlog' (stories that have no
  # iteration). Stories with a "cancelled" status are hidden by default. They
  # can be displayed by passing the request parameter 'show_cancelled' (with any
  # non-blank value).
  def index
    @page_title = "Backlog"
    SortHelper.columns = %w( scid sub_project.name title points priority risk
                             status )
    SortHelper.default_order = %w( status priority risk )
    if params['show_cancelled']
      @stories = @project.stories.backlog
    else
      @stories = @project.stories.backlog.select { |s|
        s.status != Story::Status::Cancelled
      }
    end
    @stories.sort! do |a,b|
      SortHelper.sort(a,b,params)
    end
  end

  # Displays a form for creating new story cards.
  def new
    @page_title = "Create new story cards"
    @selected_main_menu_link = :none
  end

  # Creates new story cards based on the story titles posted form the #new
  # action.
  def create
    if params[:story_card_titles].empty?
      flash[:error] = 'Please enter at least one story card title.'
      redirect_to :controller => 'stories', :action => 'new', :project_id => @project
    else
      params[:story_card_titles].each_line do |title|
        @project.stories.create(:title => title)
      end
      flash[:status] = 'New story cards created.'
      redirect_to :controller => 'stories', :action => 'index', :project_id => @project
    end
  end

  # Displays the form for editing a story card's information.
  def edit
    @page_title = "Edit story card"
    @selected_main_menu_link = :none
    register_referer
    
    if @story = session[:edit_story]
      session[:edit_story] = nil
    else
      @story = Story.find(params['id'])
    end
    @story.return_ids_for_aggregations
  end

  # Updates a story card with the information posted from the #edit action.
  def update
    @page_title = "Edit story card"
    @selected_main_menu_link = :none
    modify_risk_status_and_priority_params
    story = Story.find(params['id'])
    story.attributes = params['story']
    if story.valid?
      story.save
      flash[:status] = 'The changes to the story card have been saved.'
      
      unless redirect_to_referer
        redirect_to :controller => 'stories', :action => 'index',
                    :project_id => @project.id.to_s
      end
    else
      session[:edit_story] = story
      redirect_to :controller => 'stories', :action => 'edit',
                  :id => story.id.to_s, :project_id => @project.id.to_s
    end
  end

  # Destroys the story card identified by the 'id' request parameter.
  def delete
    Story.destroy(params['id'])
    flash[:status] = 'The story card was deleted.'
    if params['iteration_id']
      redirect_to :controller => 'iterations', :action => 'show',
                  :id => params['iteration_id'],
                  :project_id => @project.id.to_s
    else
      redirect_to :controller => 'stories', :action => 'index',
                  :project_id => @project.id.to_s
    end
  end

  # Displays the details for the story card identified by the 'id' request
  # parameter.
  def show
    @story = Story.find(params['id'])
    @selected_main_menu_link = :none
    @page_title = @story.title
  end

  # Sets the storycard's Story#owner attribute to the currently logged in user.
  def take_ownership
    story = Story.find(params['id'])
    story.owner = session[:current_user]
    story.save
    flash[:status] = "SC#{story.scid} has been updated."
    redirect_to :controller => 'iterations', :action => 'show',
                :id => story.iteration.id.to_s, :project_id => @project.id.to_s
  end

  # Sets the story's owner to nil
  def release_ownership
    story = Story.find(params['id'])
    story.owner = nil
    story.save
    flash[:status] = "SC#{story.scid} has been updated."
    redirect_to :controller => 'iterations', :action => 'show',
                :id => story.iteration.id.to_s, :project_id => @project.id.to_s
  end

  protected

  # Sets the parameter values for a story's status, priority and risk to the
  # actual objects that need to be assigned based on the integer value
  # originally passed in that parameter.
  def modify_risk_status_and_priority_params
    if params['story']
      if params['story']['status']
        params['story']['status'] =
          Story::Status.new(params['story']['status'].to_i)
      end
      if params['story']['priority']
        params['story']['priority'] =
          Story::Priority.new(params['story']['priority'].to_i)
      end
      if params['story']['risk']
        params['story']['risk'] =
          Story::Risk.new(params['story']['risk'].to_i)
      end
    end
  end
end
