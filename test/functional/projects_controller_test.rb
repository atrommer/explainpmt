require File.dirname(__FILE__) + '/../test_helper'
require 'projects_controller'

# Re-raise errors caught by the controller.
class ProjectsController; def rescue_action(e) raise e end; end

class ProjectsControllerTest < Test::Unit::TestCase
  FULL_PAGES = [:index, :new, :edit]
  POPUPS = [:add_users,:update_users]
  NO_RENDERS = [:remove_user,:delete, :create, :update]
  ALL_ACTIONS = FULL_PAGES + POPUPS + NO_RENDERS
  REQUIRED = [:delete]
  fixtures ALL_FIXTURES
  
  def setup
    @admin = User.find 1
    @user_one = User.find 2
    @user_two = User.find 3
    @project_one = Project.find 1
    @project_two = Project.find 2
    @controller = ProjectsController.new
    @request = ActionController::TestRequest.new
    @response = ActionController::TestResponse.new
    @request.session[:current_user] = @admin
  end

  def test_authentication_required
    @request.session[:current_user] = nil
    ALL_ACTIONS.each do |a|
      process a
      assert_redirected_to :controller => 'users', :action => 'login'
      assert session[:return_to]
    end
  end

  def test_admin_required
    @request.session[:current_user] = @user_one
    REQUIRED.each do |a|
      process a
      assert_redirected_to :controller => 'error', :action => 'index'
      assert_equal "You must be logged in as an administrator to " +
                   "perform the requested action.",
                   flash[:error]
    end
  end

  def test_index
    get :index
    assert_response :success
    assert_template 'index'
    assert_equal Project.find( :all, :order => 'name ASC' ),
      assigns( :projects )
  end

  def test_new
    get :new
    assert_response :success
    assert_template 'new'
    assert_kind_of Project, assigns(:project)
    assert assigns(:project).new_record?
  end

  def test_create_no_membership
    num_before_create = Project.count
    mem_num_before_create = current_user.projects.size
    post :create, 'project' => { 'name' => 'Test Create',
                                 'description' => '' }
    assert_response :success
    assert_template 'layouts/refresh_parent_close_popup'
    assert_equal num_before_create + 1, Project.count
    assert_equal mem_num_before_create, current_user.projects.size
  end

  def test_create_add_membership
    num_before_create = Project.count
    mem_num_before_create = current_user.projects.size
    post :create, 'add_me' => '1', 'project' => { 'name' => 'Test Create',
                                                  'description' => '' }
    assert_response :success
    assert_template 'layouts/refresh_parent_close_popup'
    assert_equal num_before_create + 1, Project.count
    assert_equal mem_num_before_create + 1, current_user.projects.size
  end

  def test_add_users
    get :add_users, 'project_id' => @project_one.id
    assert_response :success
    assert_equal @project_one, assigns( :project )
    assert_template 'add_users'
    available = User.find( :all, 
                           :order => 'last_name ASC, first_name ASC' ) -
                            @project_one.users
    assert_equal available, assigns( :available_users )
  end

  def test_update_users
    post :update_users, 'project_id' => @project_one.id,
         'selected_users' => [ @user_one.id, @user_two.id ]                         
    assert_response :success
    assert_template 'layouts/refresh_parent_close_popup'
    assert flash[ :status ]
    [ @user_one, @user_two ].each do |u|
      assert @project_one.users.include?(u)
    end
  end

  def test_remove_user
    get :remove_user, 'project_id' => @project_one.id, 'id' => @user_one.id
    assert_redirected_to :controller => 'users', :action => 'index',
                         :project_id => @project_one.id
    assert flash[ :status ]
    assert !@project_one.users( true ).include?( @user_one )
  end

  def test_delete
    get :delete, 'id' => @project_one.id
    assert_redirected_to :controller => 'projects', :action => 'index'
    assert flash[ :status ]
    assert_raise( ActiveRecord::RecordNotFound ) do
      Project.find @project_one.id
    end
  end

  def test_edit
    get :edit, 'id' => @project_one.id
    assert_response :success
    assert_template 'edit'
    assert_equal @project_one, assigns( :project )
  end

  def test_update
    post :update, 'id' => @project_one.id, 'project' => { 'name' => 'Test' }
    assert_response :success
    assert_template 'layouts/refresh_parent_close_popup'
    project = Project.find @project_one.id
    assert_equal 'Test', project.name
  end

  def test_my_projects_list
    @request.session[ :current_user ] = @user_one
    get :my_projects_list
    assert_response :success
    assert_template '_my_projects_list'
    assert assigns( :projects ).include?( @project_one )
    assert assigns( :projects ).include?( @project_two )
  end
  
  private

  def current_user
    @request.session[ :current_user ]
  end
end
