# frozen_string_literal: true

load './lib/common.rb'

ITEMS = [
  { name: 'space_tools' },
  # space-tools.csv
  # id,space_id,active,url,number,tool_id,type,created_at,team_permissions,watcher_permissions,public_permissions,
  # parent_id,menu_name,name
  { name: 'users' },
  # users.csv
  # id,login,name,picture,email,organization,phone,im,im2
  { name: 'user_roles' },
  # user-roles.csv
  # id,user_id,space_id,role,status,invited_time,agreed_time,title,invited_by_id
  { name: 'tags' },
  # user-tags.csv
  # id,name,space_id,state,created_at,updated_at,color
  { name: 'milestones' },
  # milestones.csv
  # id,start_date,due_date,budget,title,user_id,created_at,created_by,space_id,description,is_completed,completed_date,
  # updated_at,updated_by,release_level,release_notes,planner_type,pretty_release_level
  { name: 'tickets/statuses' },
  # tickets-statuses.csv
  # id,space_tool_id,name,state,list_order,created_at,updated_at
  { name: 'tickets/custom_fields' },
  # tickets-custom-fields.csv
  # id,space_tool_id,type,title,order,required,hide,default_value,created_at,updated_at,example_value,list_options
  { name: 'documents', q: 'per_page=100' },
  # documents.csv
  # name,content_type,created_by,id,version,filename,filesize,updated_by,description,cached_tag_list,position,url,
  # created_at,updated_at,ticket_id,attachable_type,has_thumbnail,space_id,attachable_id,attachable_guid
  { name: 'wiki_pages', q: 'per_page=10' },
  # wiki-pages.csv
  # id,page_name,contents,status,version,position,wiki_format,change_comment,parent_id,space_id,user_id,created_at,
  # updated_at
  { name: 'tickets', q: 'report=0&sort_by=number&per_page=100' }
  # tickets.csv
  # id,number,summary,description,priority,completed_date,component_id,created_on,permission_type,importance,is_story,
  # milestone_id,notification_list,space_id,state,status,story_importance,updated_at,working_hours,estimate,
  # total_estimate,total_invested_hours,total_working_hours,assigned_to_id,reporter_id,custom_fields,hierarchy_type,
  # due_date,assigned_to_name,picture_url
].freeze

export_items(ITEMS)
