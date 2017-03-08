require "fastlane_core"
require "pilot/tester_util"

module Pilot
  class TesterExporter < Manager
    def export_testers(options)
      UI.user_error!("Export file path is required") unless options[:testers_file_path]

      start(options)
      require 'csv'

      testers = testers()

      file = config[:testers_file_path]

      CSV.open(file, "w") do |csv|
        csv << ['First', 'Last', 'Email', 'Groups', 'Devices', 'Installed Version', 'Install Date']

        testers.each do |tester|
          group_names = tester.groups_list(';') || ""
          install_version = tester.full_version || ""
          pretty_date = tester.pretty_install_date || ""

          csv << [tester.first_name, tester.last_name, tester.email, group_names, tester.devices.count, install_version, pretty_date]
        end

        UI.success("Successfully exported CSV to #{file}")
      end
    end

    def export_testers_json(options)
      UI.user_error!("Export file path is required") unless options[:testers_file_path]

      start(options)
      require 'fileutils'
      require 'json'

      testers = testers()

      file = config[:testers_file_path]

      File.open(file,"w") do |f|
        testers_map = testers.map { |tester| {
          :first_name => tester.first_name,
          :last_name => tester.last_name,
          :email => tester.email,
          :groups => (tester.groups_list(';') || "").split(';'),
          :devices => tester.devices,
          :install_version => tester.latest_installed_version_number,
          :install_timestamp => tester.latest_install_date
        }}
        f.write(JSON.pretty_generate(testers_map))

        UI.success("Successfully exported json to #{file}")
      end
    end

    def testers()
      app_filter = (config[:apple_id] || config[:app_identifier])
      if app_filter
        app = Spaceship::Application.find(app_filter)
        testers = Spaceship::Tunes::Tester::External.all_by_app(app.apple_id)
      else
        testers = Spaceship::Tunes::Tester::External.all
      end
    end
  end
end
