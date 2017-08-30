# frozen_string_literal: true

load './lib/common.rb'

SPACE_NAME = 'Europeana Collections'
JIRA_PROJECT_NAME = 'Europeana Collections' + (@debug ? ' | TEST' : '')

@jira_tickets = []
@fields_jira = []

CUSTOM_FIELD_NAMES = %w(Assembla-Id Assembla-Milestone Assembla-Theme Assembla-Status Story\ Points Rank)
ISSUE_TYPE_NAMES = %w(unknown sub-task story epic task spike bug)

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

# Jira issue fields:
# -----------------
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

  project_id = @project['id']
  ticket_id = ticket['number']

  # Prepend the description text with a link to the original assembla ticket on the first line.
  description = "[Assembla ticket ##{ticket_id}|#{ENV['ASSEMBLA_URL_TICKETS']}/#{ticket_id}]\r\n\r\n#{ticket['description']}"

  story_rank = ticket['importance']
  story_points = ticket['story_importance']

  summary = ticket['summary']
  reporter_name = @user_id_to_login[ticket['reporter_id']]
  assignee_name = @user_id_to_login[ticket['assigned_to_id']]
  priority_name = @priority_id_to_name[ticket['priority']]

  status_name = ticket['status']

  labels = ['assembla']
  @tags_assembla.each do |tag|
   labels << tag['name'] if tag['ticket_id'] == ticket_id
  end

  custom_fields = JSON.parse(ticket['custom_fields'].gsub('=>',':'))
  theme_name = custom_fields['Theme']
  milestone_id = ticket['milestone_id']
  if milestone_id && milestone_id.length > 0
    milestone_name = @milestone_id_to_name[milestone_id] || milestone_id
  else
    milestone_name = ''
  end
  milestone_name = milestone_id ? @milestone_id_to_name[milestone_id] : ''
  issue_type_id = case ticket['hierarchy_type'].to_i
  when 1
    issue_type_name = 'sub-task'
    @issue_type_name_to_id['sub-task']
  when 2
    issue_type_name = 'story'
    @issue_type_name_to_id['story']
  when 3
    issue_type_name = 'epic'
    @issue_type_name_to_id['epic']
  else
    issue_type_name = 'task'
    @issue_type_name_to_id['task']
  end
  # if summary starts with EPIC, SPIKE, STORY or BUG
  # Ticket type is overruled if summary begins with the type (EPIC, SPIKE, STORY or BUG)
  %w(epic spike story bug).each do |name|
    if summary =~ /^#{name}/i
      issue_type_id = @issue_type_name_to_id[name]
      issue_type_name = name
      break
    end
  end

  payload = {
    'create': {},
    'fields': {
      'project': {
        'id': project_id
      },
      'summary': summary,
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
      'labels': labels,
      'description': description,

      # IMPORTANT: The following custom fields MUST be on the create issue screen for this project
      #  Admin > Issues > Screens > Configure screen > 'ECT: Scrum Default Issue Screen'
      # Assembla

      "#{@customfield_name_to_id['Assembla-Id']}": ticket_id,
      "#{@customfield_name_to_id['Assembla-Theme']}": theme_name,
      "#{@customfield_name_to_id['Assembla-Status']}": status_name,
      "#{@customfield_name_to_id['Assembla-Milestone']}": milestone_name,
      "#{@customfield_name_to_id['Rank']}": story_rank,

      # TODO: "customfield_10105"=>"Field 'customfield_10105' cannot be set. It is not on the appropriate screen, or unknown."
      #"#{@customfield_name_to_id['Story Points']}": story_points
    }
  }.to_json

  begin
    response = RestClient::Request.execute(method: :post, url: URL_JIRA_ISSUES, payload: payload, headers: JIRA_HEADERS)
    body = JSON.parse(response.body)
    jira_ticket_id = body['id']
    jira_ticket_key = body['key']
    puts "POST #{URL_JIRA_ISSUES} => OK (id='#{jira_ticket_id}' key='#{jira_ticket_key}')"

    @jira_tickets << {
        jira_ticket_id: jira_ticket_id,
        jira_ticket_key: jira_ticket_key,
        project_id: project_id,
        summary: summary,
        issue_type_id: issue_type_id,
        issue_type_name: issue_type_name,
        assignee_name: assignee_name,
        reporter_name: reporter_name,
        priority_name: priority_name,
        status_name: status_name,
        labels: labels.join('|'),
        description: description,
        assembla_ticket_id: ticket_id,
        theme_name: theme_name,
        milestone_name: milestone_name,
        story_rank: story_rank,
        story_points: story_points
    }

  rescue RestClient::ExceptionWithResponse => e
    errmsg = JSON.parse(e.response)
    puts "POST #{URL_JIRA_ISSUES} => NOK (#{errmsg['errors'].inspect})"
    exit
  rescue => e
    puts "POST #{URL_JIRA_ISSUES} => NOK (#{e.message})"
    exit
  end
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
comments_assembla_csv = "#{dirname_assembla}/ticket-comments.csv"
tags_assembla_csv = "#{dirname_assembla}/ticket-tags.csv"
tickets_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-tickets.csv"
issue_types_jira_csv = "#{OUTPUT_DIR_JIRA}/jira-issue-types.csv"

@tickets_assembla = csv_to_array(tickets_assembla_csv)
@users_assembla = csv_to_array(users_assembla_csv)
@milestones_assembla = csv_to_array(milestones_assembla_csv)
@comments_assembla = csv_to_array(comments_assembla_csv)
@tags_assembla = csv_to_array(tags_assembla_csv)
@issue_types_jira = csv_to_array(issue_types_jira_csv)

@user_id_to_login = {}
@users_assembla.each do |user|
  @user_id_to_login[user['id']] = user['login']
end

puts @user_id_to_login.inspect

@milestone_id_to_name = {}
@milestones_assembla.each do |milestone|
  @milestone_id_to_name[milestone['id']] = milestone['title']
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

puts
puts "Custom fields:"

@customfield_name_to_id = {}

CUSTOM_FIELD_NAMES.each do |name|
  field = jira_get_field_by_name(name)
  if field
    id = field['id']
    @customfield_name_to_id[name] = id
    puts "#{name}='#{id}'"
  else
    puts "Custom field '#{name}' is missing, please define in Jira"
    exit
  end
end

@tickets_assembla.each do |ticket|
  create_ticket_jira(ticket)
end

write_csv_file(tickets_jira_csv, @jira_tickets)