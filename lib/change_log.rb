#!/usr/bin/env ruby

require 'octokit'
require 'date'
require 'optparse'
require 'optparse/date'

# Instructions:
#
# Example:
#   ruby change_log.rb -t abcdefghijklmnopqrstuvwxyz -s 2017-09-06
#
#

class ChangeLog
  def initialize(user_and_repo, start_date = Date.today - 90, end_date = Date.today, apikey = nil)
    @user_and_repo = user_and_repo
    @apikey = apikey
    @start_date = start_date
    @end_date = end_date

    # Convert dates to time objects
    @start_date = Time.parse(@start_date.to_s) if start_date.is_a? String
    @end_date = Time.parse(@end_date.to_s) if end_date.is_a? String
    # GitHub API uses Time and not the Date class, so ensure that we have Time
    @start_date = Time.parse(@start_date.to_s)
    @end_date = Time.parse(@end_date.to_s)

    @total_open_issues = []
    @total_open_pull_requests = []
    @new_issues = []
    @closed_issues = []
    @accepted_pull_requests = []

    begin
      @github = Octokit::Client.new
      if apikey
        @github = Octokit::Client.new(access_token: apikey)
      end
      @github.auto_paginate = true
    rescue StandardError => e
      puts e.message
      # write out the help message
      ChangeLog.help
      exit(1)
    end
  end

  # Class method to show how to use the API through Rake.
  def self.help
    puts 'Usage: bundle exec rake openstudio:change_log[<start_date>,<end_date>,<apikey>]'
    puts '       <start_date> = [Optional] Start of data (e.g., 2020-09-06), defaults to 90 days before today'
    puts '       <end_date> = [Optional] End of data (e.g., 2020-10-06), default to today'
    puts '       <apikey> = [Optional] GitHub API Key (used for private repos)'
    puts
    puts '  Ensure that the GitHub user/repo is set in your Rakefile, for example, '
    puts "    rake_task.set_extension_class(OpenStudio::Extension::Extension, 'nrel/openstudio-extension-gem')"
    puts
    puts '  Example usages:'
    puts '    bundle exec rake openstudio:change_log[2020-01-01]'
    puts '    bundle exec rake openstudio:change_log[2020-01-01,2020-06-30]'
    puts '    bundle exec rake openstudio:change_log[2020-01-01,2020-01-10,<private_api_key>]'
    puts
    puts '  Notes:'
    puts '    For creating token, see https://github.com/settings/tokens.'
    puts '    Note that if passing apikey, then you must pass start_date and end_date as well. There must be no spaces'
    puts '    between the arguments (see examples above).'
  end

  # Process Open Issues
  def process
    @github.list_issues(@user_and_repo, state: 'all').each do |issue|
      if issue.state == 'open'
        if issue.pull_request
          if issue.created_at >= @start_date && issue.created_at <= @end_date
            @total_open_pull_requests << issue
          end
        else
          @total_open_issues << issue
          if issue.created_at >= @start_date && issue.created_at <= @end_date
            @new_issues << issue
          end
        end
      else
        # the issue is closed
        if issue.closed_at >= @start_date && issue.closed_at <= @end_date
          if issue.pull_request
            @accepted_pull_requests << issue
          else
            @closed_issues << issue
          end
        end
      end
    end

    @closed_issues.sort! { |x, y| x.number <=> y.number }
    @new_issues.sort! { |x, y| x.number <=> y.number }
    @accepted_pull_requests.sort! { |x, y| x.number <=> y.number }
    @total_open_pull_requests.sort! { |x, y| x.number <=> y.number }
  rescue StandardError => e
    puts e.message
    ChangeLog.help
    exit(1)
  end

  def print_issue(issue)
    is_feature = false
    issue.labels.each { |label| is_feature = true if label.name == 'Feature Request' }

    if is_feature
      "- Improved [##{issue.number}]( #{issue.html_url} ), #{issue.title}"
    else
      "- Fixed [\##{issue.number}]( #{issue.html_url} ), #{issue.title}"
    end
  end

  def print_issues
    puts "Total Open Issues: #{@total_open_issues.length}"
    puts "Total Open Pull Requests: #{@total_open_pull_requests.length}"
    puts "\nDate Range: #{@start_date.strftime('%m/%d/%y')} - #{@end_date.strftime('%m/%d/%y')}:"
    puts "\nNew Issues: #{@new_issues.length} (" + @new_issues.map(&:number).join(', ') + ')'

    puts "\nClosed Issues: #{@closed_issues.length}"
    @closed_issues.each { |issue| puts print_issue(issue) }

    puts "\nAccepted Pull Requests: #{@accepted_pull_requests.length}"
    @accepted_pull_requests.each { |issue| puts print_issue(issue) }

    puts "\nAll Open Issues: #{@total_open_issues.length} (" + @total_open_issues.map { |issue| "\##{issue.number}" }.join(', ') + ')'
  end
end
