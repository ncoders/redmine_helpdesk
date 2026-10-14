require File.dirname(__FILE__) + '/../test_helper'

class SettingsControllerWithHelpdeskTest < ActionController::TestCase
  fixtures :all

  def setup
    User.current = nil
    @controller = SettingsController.new
    @request.session[:user_id] = 1 # admin
    Setting.mail_from = 'redmine@acme.example'
  end

  def teardown
    Setting.clear_cache
  end

  def test_render_plugin_settings
    get :plugin, :params => {:id => 'redmine_helpdesk'}
    assert_response :success
    assert_select 'input[name=?]', 'settings[subject_prefix]'
    assert_select 'input[type=checkbox][name=?][checked=checked]', 'settings[own_host_only]'
    assert_select 'em.info', :text => /@acme\.example/
  end

  def test_save_plugin_settings
    post :plugin, :params => {:id => 'redmine_helpdesk',
                              :settings => {:subject_prefix => 'ACME', :own_host_only => '0'}}
    assert_redirected_to '/settings/plugin/redmine_helpdesk'
    assert_equal 'ACME', RedmineHelpdesk::SubjectPrefix.prefix
    assert !RedmineHelpdesk::SubjectPrefix.own_host_only?
  end
end
