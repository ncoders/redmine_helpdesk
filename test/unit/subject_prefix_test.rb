require File.dirname(__FILE__) + '/../test_helper'

class SubjectPrefixTest < ActiveSupport::TestCase
  self.use_transactional_tests = true

  fixtures :all

  def setup
    ActionMailer::Base.deliveries.clear
    Setting.mail_from = 'redmine@acme.example'
    Setting.host_name = 'mydomain.foo'
    Setting.plugin_redmine_helpdesk = {'subject_prefix' => 'ACME', 'own_host_only' => '1'}
  end

  def teardown
    Setting.clear_cache
  end

  # Settings

  def test_prefix_strips_characters_breaking_the_subject_tag
    Setting.plugin_redmine_helpdesk = {'subject_prefix' => ' [AC#ME] '}
    assert_equal 'ACME', RedmineHelpdesk::SubjectPrefix.prefix
  end

  def test_disabled_without_prefix
    Setting.plugin_redmine_helpdesk = {'subject_prefix' => ' '}
    assert !RedmineHelpdesk::SubjectPrefix.enabled?
  end

  def test_own_host_only_defaults_to_true
    Setting.plugin_redmine_helpdesk = {'subject_prefix' => 'ACME'}
    assert RedmineHelpdesk::SubjectPrefix.own_host_only?
  end

  def test_own_host_from_mail_from
    Setting.mail_from = 'Redmine <redmine@acme.example>'
    assert_equal 'acme.example', RedmineHelpdesk::SubjectPrefix.own_host
  end

  # Outgoing subjects

  def test_supportclient_subject_with_prefix
    email = HelpdeskMailer.email_to_supportclient(Issue.find(1), :recipient => 'owner@example.com')
    assert_equal "[ACME #1] Can't print recipes", email.subject
  end

  def test_supportclient_subject_without_prefix
    Setting.plugin_redmine_helpdesk = {'subject_prefix' => ''}
    email = HelpdeskMailer.email_to_supportclient(Issue.find(1), :recipient => 'owner@example.com')
    assert_equal "[Helpdesk Project 1 - #1] Can't print recipes", email.subject
  end

  def test_issue_add_subject_with_prefix
    with_settings :show_status_changes_in_mail_subject => '0' do
      email = Mailer.issue_add(User.find(1), Issue.find(1))
      assert_equal "[ACME Helpdesk Project 1 - Bug #1] Can't print recipes", email.subject
    end
  end

  def test_issue_add_subject_with_prefix_and_status
    with_settings :show_status_changes_in_mail_subject => '1' do
      email = Mailer.issue_add(User.find(1), Issue.find(1))
      assert_equal "[ACME Helpdesk Project 1 - Bug #1] (#{Issue.find(1).status.name}) Can't print recipes",
                   email.subject
    end
  end

  def test_issue_add_subject_without_prefix
    Setting.plugin_redmine_helpdesk = {'subject_prefix' => ''}
    with_settings :show_status_changes_in_mail_subject => '0' do
      email = Mailer.issue_add(User.find(1), Issue.find(1))
      assert_equal "[Helpdesk Project 1 - Bug #1] Can't print recipes", email.subject
    end
  end

  def test_issue_edit_subject_with_prefix
    email = Mailer.issue_edit(User.find(1), Journal.find(1))
    assert_equal "[ACME Helpdesk Project 1 - Bug #1] Can't print recipes", email.subject
  end

  def test_issue_edit_subject_without_prefix
    Setting.plugin_redmine_helpdesk = {'subject_prefix' => ''}
    email = Mailer.issue_edit(User.find(1), Journal.find(1))
    assert_equal "[Helpdesk Project 1 - Bug #1] Can't print recipes", email.subject
  end

  # Incoming subjects

  def test_reply_with_prefix
    assert_reply_to_issue 1, receive_email('Re: [ACME #1] Can\'t print recipes')
  end

  def test_reply_with_prefix_of_internal_notification
    assert_reply_to_issue 1, receive_email('Re: [ACME Helpdesk Project 1 - Bug #1] Can\'t print recipes')
  end

  def test_reply_with_prefix_is_case_insensitive
    assert_reply_to_issue 1, receive_email('Re: [acme #1] Can\'t print recipes')
  end

  def test_reply_with_prefix_after_foreign_reference
    assert_reply_to_issue 1, receive_email('Re: [Foo #2] [ACME #1] Can\'t print recipes')
  end

  def test_foreign_reference_creates_new_issue
    assert_new_issue receive_email('Re: [Foo #1] Printer broken')
  end

  def test_foreign_reference_creates_new_issue_for_supportclient
    issue = receive_email('Re: [Foo #1] Printer broken')
    assert_new_issue issue
    assert_equal 'john.doe@somenet.foo',
                 issue.reload.custom_field_value(CustomField.find_by_name('owner-email'))
    mail = ActionMailer::Base.deliveries.detect {|m| m.to.include?('john.doe@somenet.foo')}
    assert_not_nil mail
    assert_equal "[ACME ##{issue.id}] Re: [Foo #1] Printer broken", mail.subject
  end

  def test_reference_without_prefix_creates_new_issue
    assert_new_issue receive_email('Re: [Helpdesk Project 1 - Bug #1] Can\'t print recipes')
  end

  def test_reference_with_longer_prefix_creates_new_issue
    assert_new_issue receive_email('Re: [ACMEX #1] Printer broken')
  end

  def test_foreign_reference_updates_issue_without_prefix
    Setting.plugin_redmine_helpdesk = {'subject_prefix' => ''}
    assert_reply_to_issue 1, receive_email('Re: [Foo #1] Printer broken')
  end

  # Incoming headers

  def test_reply_with_own_message_id
    assert_reply_to_issue 1, receive_email('Re: Printer broken',
                                           'In-Reply-To' => '<redmine.issue-1.20060719210421@acme.example>')
  end

  def test_reply_with_own_message_id_of_supportclient_mail
    assert_reply_to_issue 1, receive_email('Re: Printer broken',
                                           'In-Reply-To' => '<redmine.issue-1.20060719210421.0123456789abcdef@ACME.example>')
  end

  def test_reply_with_own_message_id_in_references
    assert_reply_to_issue 1, receive_email('Re: Printer broken',
                                           'References' => '<other@mail.example> <redmine.issue-1.20060719210421@acme.example>')
  end

  def test_foreign_message_id_creates_new_issue
    assert_new_issue receive_email('Re: Printer broken',
                                   'In-Reply-To' => '<redmine.issue-1.20060719210421@othercorp.example>')
  end

  def test_foreign_message_id_with_prefixed_subject_replies_by_subject
    assert_reply_to_issue 2, receive_email('Re: [ACME #2] Add ingredients categories',
                                           'In-Reply-To' => '<redmine.issue-1.20060719210421@othercorp.example>')
  end

  def test_foreign_message_id_updates_issue_without_own_host_only
    Setting.plugin_redmine_helpdesk = {'subject_prefix' => 'ACME', 'own_host_only' => '0'}
    assert_reply_to_issue 1, receive_email('Re: Printer broken',
                                           'In-Reply-To' => '<redmine.issue-1.20060719210421@othercorp.example>')
  end

  private

  def receive_email(subject, headers={})
    raw = +"From: John Doe <john.doe@somenet.foo>\n"
    raw << "To: redmine@acme.example\n"
    raw << "Subject: #{subject}\n"
    raw << "Message-ID: <#{SecureRandom.hex(8)}@somenet.foo>\n"
    headers.each {|k, v| raw << "#{k}: #{v}\n"}
    raw << "\nThis is a reply\n"
    MailHandler.receive(raw,
                        :issue => {:project => 'helpdesk_project_1'},
                        :unknown_user => 'accept',
                        :no_permission_check => '1')
  end

  def assert_reply_to_issue(issue_id, result)
    assert_kind_of Journal, result
    assert_equal issue_id, result.journalized_id
    assert_include 'This is a reply', result.notes
  end

  def assert_new_issue(result)
    assert_kind_of Issue, result
    assert !result.new_record?
  end
end
