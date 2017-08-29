# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = 'Europeana Collections'
JIRA_PROJECT_NAME = 'Europeana Collections' + (@debug ? ' | TEST' : '')

@jira_tickets = []

# Assembla ticket fields:
# ----------------------
# id
# * number
# * summary
# * description
# * priority (1 - Highest, 2 - High, 3 - Medium, 4 - Low, 5 - Lowest)
# completed_date
# component_id
# * created_on
# permission_type
# * importance (Sorting criteria for Assembla Planner) => 10104 Rank
# is_story (true or false, if true hierarchy_type = 2)
# milestone_id => 10103 Sprint
# notification_list
# * space_id
# state (0 - closed, 1 - open)
# status (new, blocked, testable, in acceptance testing, in progress, ready for deploy)
# * story_importance (1 - small, 4 - medium, 7 - large) => 10105 Story Points
# updated_at
# working_hours
# estimate
# total_estimate
# total_invested_hours
# total_working_hours
# * assigned_to_id
# * reporter_id
# custom_fields
# hierarchy_type (0 - No plan level, 1 - Subtask, 2 - Story, 3 - Epic)
# # due_date

# Jira custom fields:
# ------------------
# * issuetype
# timespent
# * project
# fixVersions
# aggregatetimespent
# resolution
# resolutiondate
# workratio
# lastViewed
# watches
# thumbnail
# * created
# * priority
# * labels
# timeestimate
# aggregatetimeoriginalestimate
# versions
# issuelinks
# * assignee
# * updated
# status
# components
# issuekey
# timeoriginalestimate
# * description
# timetracking
# security
# attachment
# aggregatetimeestimate
# * summary
# * creator
# subtasks
# * reporter
# aggregateprogress
# environment
# duedate
# progress
# comment
# votes
# worklog

# Jira custom fields:
# ------------------
# 10000 Development
# 10001 Team
# 10002 Organizations
# 10003 Epic Name
# 10004 Epic Status
# 10005 Epic Color
# 10006 Epic Link
# 10007 Parent Link
# 10100 [CHART] Date of First Response
# 10101 [CHART] Time in Status
# 10102 Approvals
# * 10103 Sprint
# * 10104 Rank
# * 10105 Story Points
# 10108 Test sessions
# 10109 Raised during
# 10200 Testing status
# 10300 Capture for JIRA user agent
# 10301 Capture for JIRA browser
# 10302 Capture for JIRA operating system
# 10303 Capture for JIRA URL
# 10304 Capture for JIRA screen resolution
# 10305 Capture for JIRA jQuery version
# 10400 Assembla

def jira_get_field_by_name(name)
  @fields_jira.find{ |field| field['name'] == name }
end

def create_ticket_jira(ticket)
  summary = ticket['summary']
  reporter_name = @user_id_to_login[ticket['reporter_id']]
  assignee_name = @user_id_to_login[ticket['assigned_to_id']]
  priority_name = @priority_id_to_name[ticket['priority']]
  milestone_id = ticket['milestone_id']
  milestone_name = milestone_id ? @milestone_id_to_name[milestone_id] : ''
  issue_type_id = case ticket['hierarchy_type'].to_i
  when 1
    @issue_type_name_to_id['sub-task']
  when 2
    @issue_type_name_to_id['story']
  when 3
    @issue_type_name_to_id['epic']
  else
    @issue_type_name_to_id['task']
  end
  # if summary starts with EPIC, SPIKE, STORY or BUG
  # Ticket type is overruled if summary begins with the type (EPIC, SPIKE, STORY or BUG)
  %w(epic spike story bug).each do |issue_type_name|
    if summary =~ /^#{issue_type_name}/i
      issue_type_id = @issue_type_name_to_id[issue_type_name]
      break
    end
  end

  payload = {
    'create': {},
    'fields': {
      'project': {
        'id': @project['id']
      },
      'summary': ticket['summary'],
      'issuetype': {
        'id': issue_type_id
      },
      'assignee': {
        'name': assignee_name
      },
      'reporter': {
        'name': reporter_name
      },
      'priority': {
        'name': priority_name
      },
      'labels': [
        'assembla'
      ],
      'description': ticket['description'],
      'created': ticket['created_on'],
      'updated': ticket['updated_at'],
      "#{@customfield_assembla['id']}": ticket['number'],
      # 10103 Sprint
      #"customfield_10103": milestone_name,
      # 10104 Rank
      "customfield_10104": ticket['importance'],
      # 10105 Story Points
      "customfield_10105": ticket['story_importance']
    }
  }.to_json

  puts JSON.parse(payload).inspect

  begin
    response = RestClient::Request.execute(method: :post, url: URL_JIRA_ISSUES, payload: payload, headers: JIRA_HEADERS)
    body = JSON.parse(response.body)
    puts "POST #{URL_JIRA_ISSUES} => OK #{body.to_json}"
    @jira_tickets << body
    result = true
  rescue => e
    puts "POST #{URL_JIRA_ISSUES} => NOK (#{e.message})"
  end

  puts "done"
end

# Ensure that the project exists, otherwise ask the user to create it first.
@project = get_project_by_name(JIRA_PROJECT_NAME)

if @project
  puts "Found project '#{JIRA_PROJECT_NAME}' id='#{@project['id']}' key='#{@project['key']}'"
else
  puts "You must first create a Jira project called '#{JIRA_PROJECT_NAME}' in order to continue"
  exit
end

space = get_space(SPACE_NAME)
dirname_assembla = get_output_dirname(space, 'assembla')
tickets_assembla_csv = "#{dirname_assembla}/tickets.csv"
users_assembla_csv = "#{dirname_assembla}/users.csv"
milestones_assembla_csv = "#{dirname_assembla}/milestones.csv"
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
issue_types_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-issue-types.csv"

@tickets_assembla = csv_to_array(tickets_assembla_csv)
@users_assembla = csv_to_array(users_assembla_csv)
@milestones_assembla = csv_to_array(milestones_assembla_csv)
@issue_types_jira = csv_to_array(issue_types_jira_csv)

@user_id_to_login = {}
@users_assembla.each do |user|
  @user_id_to_login[user['id']] = user['login']
end

puts @user_id_to_login.inspect

@milestones_id_to_name = {}
@milestones_assembla.each do |milestone|
  @milestones_id_to_name[milestone['id']] = milestone['title']
end

puts @user_id_to_login.inspect

@issue_type_name_to_id = {}
@issue_types_jira.each do |type|
  name = type['name'].downcase
  id = type['id']
  puts "id=#{id} name='#{name}'"
  @issue_type_name_to_id[name] = id
end

@priority_id_to_name = {}
@priorities_jira = jira_get_priorities
if @priorities_jira
  @priorities_jira.each do |priority|
    name = priority['name']
    id = priority['id']
    puts "id=#{id} name='#{name}'"
    @priority_id_to_name[id] = name
  end
else
  puts "Cannot get priorities!"
  exit
end

@fields_jira = jira_get_fields
if @fields_jira
  @fields_jira.each do |field|
    puts "id=#{field['id']} name='#{field['name']}' #{field['custom']}"
  end
else
  puts "Cannot get fields!"
  exit
end

@customfield_assembla = jira_get_field_by_name('Assembla')
if @customfield_assembla
  puts "Assembla id = '#{@customfield_assembla['id']}'"
else
  puts "Assembla custom field is missing, please define in Jira"
  exit
end

@tickets_assembla.each do |ticket|
  create_ticket_jira(ticket)
end

# write_csv_file(jira_tickets_csv, @jira_tickets)