#!/usr/bin/env ruby
# frozen_string_literal: true

require 'octokit'
require 'date'
require 'optparse'
require 'optparse/date'

# Instructions:
#   Get a token from github's settings (https://github.com/settings/tokens)
#
# Example:
#   ruby change_log.rb -t abcdefghijklmnopqrstuvwxyz -s 2017-09-06
#
#

### Repository options
repo_owner = 'NREL'
repo = 'openstudio-extension-gem'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: change_log.rb [options]\n" \
                'Prints New, Open, Closed Issues, and number of accepted PRs'
  opts.separator ''

  # defaults, go back 90 days
  options[:start_date] = Date.today - 90
  options[:end_date] = Date.today

  opts.on('-s', '--start-date [DATE]', Date, 'Start of data (e.g. 2020-09-06)') do |v|
    options[:start_date] = v
  end
  opts.on('-e', '--end-date [DATE]', Date, 'End of data (e.g. 2020-09-13)') do |v|
    options[:end_date] = v
  end
  opts.on('-t', '--token [String]', String, 'Github API Token') do |v|
    options[:token] = v
  end
end.parse!

# Convert dates to time objects
options[:start_date] = Time.parse(options[:start_date].to_s)
options[:end_date] = Time.parse(options[:end_date].to_s)
puts options


github = Octokit::Client.new
if options[:token]
  puts 'Using github token'
  github = Octokit::Client.new(access_token: options[:token])
end
github.auto_paginate = true

total_open_issues = []
total_open_pull_requests = []
new_issues = []
closed_issues = []
total_closed_pull_requests = []
accepted_pull_requests = []

def print_issue(issue)
  is_feature = false
  issue.labels.each { |label| is_feature = true if label.name == 'Feature Request' }

  if is_feature
    "- Improved [##{issue.number}]( #{issue.html_url} ), #{issue.title}"
  else
    "- Fixed [\##{issue.number}]( #{issue.html_url} ), #{issue.title}"
  end
end

# Process Open Issues
github.list_issues("#{repo_owner}/#{repo}", state: 'all').each do |issue|
  puts(issue.inspect)
  if issue.state == 'open'
    if issue.pull_request
      if issue.created_at >= options[:start_date] && issue.created_at <= options[:end_date]
        total_open_pull_requests << issue
      end
    else
      total_open_issues << issue
      if issue.created_at >= options[:start_date] && issue.created_at <= options[:end_date]
        new_issues << issue
      end
    end
  else
    # the issue is closed
    if issue.closed_at >= options[:start_date] && issue.closed_at <= options[:end_date]
      if issue.pull_request
        accepted_pull_requests << issue
      else
        closed_issues << issue
      end
    end
  end
end

closed_issues.sort! { |x, y| x.number <=> y.number }
new_issues.sort! { |x, y| x.number <=> y.number }
accepted_pull_requests.sort! { |x, y| x.number <=> y.number }
total_open_pull_requests.sort! { |x, y| x.number <=> y.number }

puts "Total Open Issues: #{total_open_issues.length}"
puts "Total Open Pull Requests: #{total_open_pull_requests.length}"
puts "\nDate Range: #{options[:start_date].strftime('%m/%d/%y')} - #{options[:end_date].strftime('%m/%d/%y')}:"
puts "\nNew Issues: #{new_issues.length} (" + new_issues.map { |issue| issue.number }.join(', ') + ')'

puts "\nClosed Issues: #{closed_issues.length}"
closed_issues.each { |issue| puts print_issue(issue) }

puts "\nAccepted Pull Requests: #{accepted_pull_requests.length}"
accepted_pull_requests.each { |issue| puts print_issue(issue) }

puts "\nAll Open Issues: #{total_open_issues.length} (" + total_open_issues.map { |issue| issue.number }.join(', ') + ')'
