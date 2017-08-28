# frozen_string_literal: true

require 'json'
require 'csv'
require 'fileutils'
require 'dotenv/load'
require 'rest-client'

SPACE_NAMES = [
  'Europeana APIs',
  'Europeana Infrastructure',
  'Europeana Collections'
].freeze

ASSEMBLA_API_HOST = ENV['ASSEMBLA_API_HOST']
ASSEMBLA_API_KEY = ENV['ASSEMBLA_API_KEY']
ASSEMBLA_API_SECRET = ENV['ASSEMBLA_API_SECRET']
ASSEMBLA_HEADERS = { 'X-Api-Key': ASSEMBLA_API_KEY, 'X-Api-Secret': ASSEMBLA_API_SECRET }.freeze

JIRA_API_HOST = ENV['JIRA_API_HOST']
JIRA_API_USERNAME = ENV['JIRA_API_USERNAME']
JIRA_API_PASSWORD = ENV['JIRA_API_PASSWORD']
JIRA_API_AUTHORIZATION = ENV['JIRA_API_AUTHORIZATION']
JIRA_HEADERS = { 'Authorization': "Basic #{JIRA_API_AUTHORIZATION}", 'Content-Type': 'application/json' }

URL_JIRA_PROJECT = "#{JIRA_API_HOST}/project"
URL_JIRA_ISSUE_TYPES = "#{JIRA_API_HOST}/issuetype"

OUTPUT_DIR = 'data'

def build_counter(opts)
  opts[:counter] ? "[#{opts[:counter]}/#{opts[:total]}] " : ''
end

def http_request(url, opts = {})
  response = ''
  url = "#{url}?per_page=#{opts[:per_page]}&page=#{opts[:page]}" if opts[:per_page]
  counter = build_counter(opts)
  begin
    response = RestClient::Request.execute(method: :get, url: url, headers: ASSEMBLA_HEADERS)
    count = get_response_count(response)
    puts "#{counter}GET #{url} => OK (#{count})"
  rescue => e
    if e.class == RestClient::NotFound && e.response.match?(/Tool not found/i)
      puts "#{counter}GET #{url} => OK (0)"
    else
      puts "#{counter}GET #{url} => NOK (#{e.message})"
      exit
    end
  end
  response
end

def get_response_count(response)
  return 0 if response.nil? || !response.is_a?(String) || response.length.zero?
  begin
    json = JSON.parse(response)
    return 0 unless json.is_a?(Array)
     return json.length
  rescue => e
    return 0
  end
end

def get_space(name)
  response = http_request("#{ASSEMBLA_API_HOST}/spaces")
  json = JSON.parse(response.body)
  space = json.find { |s| s['name'] == name }
  unless space
    puts "Couldn't find space with name = '#{name}'"
    exit
  end
  space
end

def get_items(items, space)
  items.each do |item|
    url = "#{ASSEMBLA_API_HOST}/spaces/#{space['id']}/#{item[:name]}"
    page = 0
    in_progress = true
    item[:results] = []
    while in_progress
      response = http_request(url, per_page: item[:per_page], page: page)
      count = get_response_count(response)
      if count.positive?
        JSON.parse(response).each do |rec|
          item[:results] << rec
        end
        item[:per_page] ? page += 1 : in_progress = false
      else
        in_progress = false
      end
    end
  end
  items
end

def create_csv_files(space, items)
  items = [items] unless items.is_a?(Array)
  items.each do |item|
    create_csv_file(space, item)
  end
  puts "#{space['name']} #{items.map{|item| item[:name]}.to_json} => done!"
end

def create_csv_file(space, item)
  dirname = get_output_dirname(space)
  filename = "#{dirname}/#{normalize_name(item[:name])}.csv"
  write_csv_file(filename, item[:results])
end

def export_items(list)
  SPACE_NAMES.each do |space_name|
    space = get_space(space_name)
    items = get_items(list, space)
    create_csv_files(space, items)
  end
end

def write_csv_file(filename, results)
  puts filename
  CSV.open(filename, 'wb') do |csv|
    results.each_with_index do |result, index|
      csv << result.keys if index.zero?
      row = []
      result.keys.each do |field|
        row.push(result[field])
      end
      csv << row
    end
  end
end

def get_output_dirname(space, dir = nil)
  dirname = "#{OUTPUT_DIR}/#{normalize_name(space['name'])}" + (dir ? "/#{normalize_name(dir)}": '')
  FileUtils.mkdir_p(dirname) unless File.directory?(dirname)
  dirname
end

def normalize_name(s)
  s.downcase.tr(' /_', '-')
end

def csv_to_array(pathname)
  csv = CSV::parse(File.open(pathname, 'r') {|f| f.read })
  fields = csv.shift
  fields = fields.map {|f| f.downcase.tr(' ', '_')}
  csv.collect { |record| Hash[*fields.zip(record).flatten ] }
end
