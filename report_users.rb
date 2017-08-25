# frozen_string_literal: true

load './lib/common.rb'

@users = []
@users_index = {}
@num_unknowns = 0

@debug = true

FILES = [
  { name: 'documents', fields: %w[created_by] },
  { name: 'milestones', fields: %w[created_by] },
  { name: 'ticket-attachments', fields: %w[created_by] },
  { name: 'ticket-comments', fields: %w[user_id] },
  { name: 'tickets', fields: %w[assigned_to_id reporter_id] },
  { name: 'user-roles', fields: %w[user_id invited_by_id] },
  { name: 'wiki-pages', fields: %w[user_id] }
].freeze

def abort(message)
  puts message
  exit
end

def create_user_index(user, space)
  # Some sanity checks just in case
  abort('create_user_index() => NOK (user is undefined)') unless user
  abort('create_user_index() => NOK (user must be a hash)') unless user.is_a?(Hash)
  abort('create_user_index() => NOK (user id is undefined)') unless user['id']

  id = user['id']
  login = user['login']
  name = user['name']

  unless @users_index[user['id']].nil?
    puts "create_user_index(space='#{space['name']}',id=#{id},login=#{login},name='#{name}' => OK (already exists)"
    return
  end

  user_index = {}

  FILES.each do |file|
    fname = file[:name]
    fields = file[:fields]
    user_index_name = {}
    fields.each do |field|
      user_index_name[field] = []
    end
    user_index[fname] = user_index_name
  end

  user_index['count'] = 0
  user_index['login'] = login
  user_index['name'] = name
  @users_index[id] = user_index
  puts "create_user_index(space='#{space['name']}',id=#{id},login=#{login},name='#{name}' => OK"

  user_index
end

SPACE_NAMES.each do |name|
  space = get_space(name)
  output_dirname = get_output_dirname(space)
  csv_to_array("#{output_dirname}/users.csv").each do |row|
    @users << row
  end
end

SPACE_NAMES.each do |name|
  if @debug
    # For the time being only this space
    next unless name == 'Europeana Collections'
  end
  space = get_space(name)
  output_dirname = get_output_dirname(space)
  puts "#{name}: found #{@users.length} users"
  @users.each do |user|
    create_user_index(user, space)
  end
  FILES.each do |file|
    fname = file[:name]
    pathname = "#{output_dirname}/#{fname}.csv"
    puts pathname
    csv_to_array(pathname).each do |h|
      file[:fields].each do |f|
        user_id = h[f]
        # Ignore empty user ids.
        next unless user_id && user_id.length.positive?
        user_index = @users_index[user_id]
        unless user_index
          @num_unknowns += 1
          h = {}
          h['id'] = user_id
          h['login'] = "unknown-#{@num_unknowns}"
          h['name'] = "Unknown ##{@num_unknowns}"
          user_index = create_user_index(h, space)
        end
        user_index['count'] += 1
        user_item = user_index[fname]
        user_item_field = user_item[f]
        user_item_field << h
      end
    end
  end

  pathname_report = "#{output_dirname}/report-user-activity.csv"
  CSV.open(pathname_report, 'wb') do |csv|
    @users_index.sort_by{ |u| -u[1]['count'] }.each_with_index do |user_index, index|
      fields = FILES.map{ |file| file[:fields].map { |field| "#{file[:name]}:#{field}"} }.flatten
      keys = %w[count id login name picture email organization phone] + fields
      csv << keys if index.zero?
      id = user_index[0]
      count = user_index[1]['count']
      login = user_index[1]['login']
      name = user_index[1]['name']
      picture = user_index[1]['picture']
      email = user_index[1]['email']
      organization = user_index[1]['organization']
      phone = user_index[1]['phone']
      row = [count, id, login, name, picture, email, organization, phone]
      fields.each do |f|
        f1, f2 = f.split(':')
        row << user_index[1][f1][f2].length
      end
      csv << row
      puts "#{count.to_s.rjust(4)} #{id} #{login}"
    end
  end
  puts pathname_report
end

