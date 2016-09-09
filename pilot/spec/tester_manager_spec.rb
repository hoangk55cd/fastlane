require 'colored'
require 'ostruct'

describe Pilot::TesterManager do
  let(:global_testers) do
    [
      OpenStruct.new(
        first_name: 'First',
        last_name: 'Last',
        email: 'my@email.addr',
        groups: ['testers'],
        devices: ['d'],
        full_version: '1.0 (21)',
        pretty_install_date: '2016-01-01',
        something_else: 'blah'
      ),
      OpenStruct.new(
        first_name: 'Fabricio',
        last_name: 'Devtoolio',
        email: 'fabric-devtools@gmail.com',
        groups: ['testers'],
        devices: ['d', 'd2'],
        full_version: '1.1 (22)',
        pretty_install_date: '2016-02-02',
        something_else: 'blah'
      )
    ]
  end

  let(:app_context_testers) do
    [
      OpenStruct.new(
        first_name: 'First',
        last_name: 'Last',
        email: 'my@email.addr',
        something_else: 'blah',
        devices: ['a']
      ),
      OpenStruct.new(
        first_name: 'Fabricio',
        last_name: 'Devtoolio',
        email: 'fabric-devtools@gmail.com',
        something_else: 'blah',
        devices: ['b']
      )
    ]
  end

  let(:fake_raw_data) { "fake_raw_data" }

  let(:tester_manager) { Pilot::TesterManager.new }

  let(:fake_apple_id) { "whatever" }
  let(:fake_app) { "fake_app_object" }

  before(:each) do
    allow(fake_app).to receive(:apple_id).and_return(fake_apple_id)
    allow(Spaceship::Application).to receive(:find).and_return(fake_app)
    allow(tester_manager).to receive(:login) # prevent attempting to log in with iTC
    allow(fake_raw_data).to receive(:get).and_return(nil)
    global_testers.each do |tester|
      allow(tester).to receive(:raw_data).and_return(fake_raw_data)
    end
    app_context_testers.each do |tester|
      allow(tester).to receive(:raw_data).and_return(fake_raw_data)
    end
  end


  describe "prints tester lists" do
    describe "when invoked from a global context" do
      it "prints a table with columns including device and version info" do
        allow(Spaceship::Tunes::Tester::Internal).to receive(:all).and_return(global_testers)
        allow(Spaceship::Tunes::Tester::External).to receive(:all).and_return(global_testers)

        headings = ["First", "Last", "Email", "Groups", "Devices", "Latest Version", "Latest Install Date"]
        rows = global_testers.map do |tester|
          [
            tester.first_name,
            tester.last_name,
            tester.email,
            tester.group_names,
            tester.devices.count,
            tester.full_version,
            tester.pretty_install_date
          ]
        end

        expect(Terminal::Table).to receive(:new).with(title: "Internal Testers".green,
                                                   headings: headings,
                                                       rows: rows)
        expect(Terminal::Table).to receive(:new).with(title: "External Testers".green,
                                                   headings: headings,
                                                       rows: rows)

        tester_manager.list_testers({})
      end
    end

    describe "when invoked from the context of an app" do
      it "prints a table without columns showing device and version info" do
        allow(Spaceship::Tunes::Tester::Internal).to receive(:all_by_app).and_return(app_context_testers)
        allow(Spaceship::Tunes::Tester::External).to receive(:all_by_app).and_return(app_context_testers)

        headings = ["First", "Last", "Email", "Groups"]
        rows = app_context_testers.map do |tester|
          [tester.first_name, tester.last_name, tester.email, tester.group_names]
        end

        expect(Terminal::Table).to receive(:new).with(title: "Internal Testers".green,
                                                   headings: headings,
                                                       rows: rows)
        expect(Terminal::Table).to receive(:new).with(title: "External Testers".green,
                                                   headings: headings,
                                                       rows: rows)

        tester_manager.list_testers(app_identifier: 'com.whatever')
      end
    end
  end

  describe "finds tester" do
    describe "when app id isn't specified" do
      it "finds an existing internal tester" do
        tester_to_find = global_testers[0]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find).with(tester_email).and_return(tester_to_find)
        allow(Spaceship::Tunes::Tester::External).to receive(:find).with(tester_email).and_return(nil)

        tester = tester_manager.find_tester(email: tester_email)
        expect(tester).to equal(tester_to_find)
      end

      it "finds an existing external tester" do
        tester_to_find = global_testers[0]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find).with(tester_email).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find).with(tester_email).and_return(tester_to_find)

        tester = tester_manager.find_tester(email: tester_email)
        expect(tester).to equal(tester_to_find)
      end

      it "fails to find a tester" do
        tester_to_find = global_testers[0]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find).with(tester_email).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find).with(tester_email).and_return(nil)

        expect(FastlaneCore::UI).to receive(:user_error!).with(/Tester #{tester_email} not found/).and_raise("boom")

        expect do
          tester_manager.find_tester(email: tester_email)
        end.to raise_error("boom") 
      end
    end

    describe "when app id is specified" do
      it "finds an existing internal tester" do
        tester_to_find = app_context_testers[1]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find_by_app).with(fake_apple_id, tester_email).and_return(tester_to_find)
        allow(Spaceship::Tunes::Tester::External).to receive(:find_by_app).with(fake_apple_id, tester_email).and_return(nil)

        tester = tester_manager.find_tester(app_identifier: 'com.whatever', email: tester_email)
      end

      it "finds an existing external tester" do
        tester_to_find = app_context_testers[1]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find_by_app).with(fake_apple_id, tester_email).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find_by_app).with(fake_apple_id, tester_email).and_return(tester_to_find)

        tester = tester_manager.find_tester(app_identifier: 'com.whatever', email: tester_email)
      end

      it "fails to find a tester" do
        tester_to_find = app_context_testers[1]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find_by_app).with(fake_apple_id, tester_email).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find_by_app).with(fake_apple_id, tester_email).and_return(nil)

        expect(FastlaneCore::UI).to receive(:user_error!).with(/Tester #{tester_email} not found/).and_raise("boom")

        expect do
          tester_manager.find_tester(app_identifier: 'com.whatever', email: tester_email)
        end.to raise_error("boom") 
      end
    end
  end

  describe "removes tester" do
    describe "when app id isn't specified" do
      it "removes internal tester" do
        tester_to_find = global_testers[0]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find).and_return(tester_to_find)
        allow(Spaceship::Tunes::Tester::External).to receive(:find).and_return(nil)
        allow(tester_to_find).to receive(:delete!).and_return(nil)

        expect(FastlaneCore::UI).to receive(:success).with(/Successfully removed tester #{tester_email}/)

        tester_manager.remove_tester(email: tester_email)
      end

      it "removes external tester" do
        tester_to_find = global_testers[0]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find).and_return(tester_to_find)
        allow(tester_to_find).to receive(:delete!).and_return(nil)

        expect(FastlaneCore::UI).to receive(:success).with(/Successfully removed tester #{tester_email}/)

        tester_manager.remove_tester(email: tester_email)
      end

      it "fails to remove a tester" do
        tester_to_find = global_testers[0]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find).and_return(tester_to_find)
        allow(tester_to_find).to receive(:delete!).and_raise("delete_failure")

        expect(FastlaneCore::UI).to receive(:error).with(/Could not remove tester #{tester_email}: /)

        expect do
          tester_manager.remove_tester(email: tester_email)
        end.to raise_error("delete_failure") 
      end

      it "fails to find a tester" do
        tester_to_find = global_testers[0]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find).and_return(nil)

        expect(FastlaneCore::UI).to receive(:error).with(/Tester #{tester_email} not found/)

        tester_manager.remove_tester(email: tester_email) 
      end
    end

    describe "when app id is specified" do
      it "removes internal tester" do
        tester_to_find = app_context_testers[1]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find_by_app).and_return(tester_to_find)
        allow(Spaceship::Tunes::Tester::External).to receive(:find_by_app).and_return(nil)
        allow(tester_to_find).to receive(:remove_from_app!).with(fake_apple_id).and_return(nil)

        expect(FastlaneCore::UI).to receive(:success).with(/Successfully removed tester #{tester_email} from app #{fake_apple_id}/)

        tester_manager.remove_tester(app_identifier: 'com.whatever', email: tester_email)
      end

      it "removes external tester" do
        tester_to_find = app_context_testers[1]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find_by_app).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find_by_app).and_return(tester_to_find)
        allow(tester_to_find).to receive(:remove_from_app!).with(fake_apple_id).and_return(nil)

        expect(FastlaneCore::UI).to receive(:success).with(/Successfully removed tester #{tester_email} from app #{fake_apple_id}/)

        tester_manager.remove_tester(app_identifier: 'com.whatever', email: tester_email)
      end

      it "fails to remove a tester" do
        tester_to_find = app_context_testers[1]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find_by_app).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find_by_app).and_return(tester_to_find)
        allow(tester_to_find).to receive(:remove_from_app!).with(fake_apple_id).and_raise("delete_failure")

        expect(FastlaneCore::UI).to receive(:error).with(/Could not remove tester #{tester_email} from app #{fake_apple_id}: /)

        expect do
          tester_manager.remove_tester(app_identifier: 'com.whatever', email: tester_email)
        end.to raise_error("delete_failure") 
      end
    end
  end

  describe "adds tester" do
    let(:new_tester) { OpenStruct.new(
        first_name: 'New_First_Name',
        last_name: 'New_Last_Name',
        email: 'new@tester.ru',
      ) }

    describe "when app id isn't specified" do
      it "adds an existing tester" do
        tester_to_find = global_testers[0]
        tester_email = tester_to_find["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find).and_return(tester_to_find)
        allow(Spaceship::Tunes::Tester::External).to receive(:find).and_return(nil)

        expect(FastlaneCore::UI).to receive(:success).with(/Existing tester #{tester_email}/)

        tester_manager.add_tester(email: tester_email)
      end

      it "adds a new tester" do
        tester_email = new_tester[:email]
        create_args_expect = { email: new_tester[:email], first_name: new_tester[:first_name], last_name: new_tester[:last_name], app_id: nil }

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:create!).with(create_args_expect).and_return(new_tester)

        expect(FastlaneCore::UI).to receive(:success).with(/Successfully invited tester: #{tester_email}/)

        tester_manager.add_tester(email: tester_email, first_name: new_tester[:first_name], last_name: new_tester[:last_name])
      end

      it "fails to add a tester" do
        tester_email = new_tester[:email]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:create!).and_raise("failed_to_add")

        expect(FastlaneCore::UI).to receive(:error).with(/Could not create tester #{tester_email}: /)

        expect do
          tester_manager.add_tester(email: tester_email, first_name: new_tester[:first_name], last_name: new_tester[:last_name])
        end.to raise_error("failed_to_add")
      end
    end

    describe "when app id is specified" do
      it "adds existing tester" do
        tester_email = new_tester["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find_by_app).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find_by_app).and_return(new_tester)
        allow(new_tester).to receive(:add_to_app!).with(fake_apple_id).and_return(nil)

        expect(FastlaneCore::UI).to receive(:success).with(/Existing tester #{tester_email}/)
        expect(FastlaneCore::UI).to receive(:success).with(/Successfully added tester to app #{fake_apple_id}/)

        tester_manager.add_tester(app_identifier: 'com.whatever', email: tester_email, first_name: new_tester[:first_name], last_name: new_tester[:last_name])
      end

      it "fails to add existing tester to app" do
        tester_email = new_tester["email"]

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find_by_app).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find_by_app).and_return(new_tester)
        allow(new_tester).to receive(:add_to_app!).with(fake_apple_id).and_raise("failed_to_add_to_app")

        expect(FastlaneCore::UI).to receive(:success).with(/Existing tester #{tester_email}/)
        expect(FastlaneCore::UI).to receive(:error).with(/Could not add tester #{tester_email} to app #{fake_apple_id}: /)

        expect do
          tester_manager.add_tester(app_identifier: 'com.whatever', email: tester_email, first_name: new_tester[:first_name], last_name: new_tester[:last_name])
        end.to raise_error("failed_to_add_to_app")
      end

      it "adds a new tester" do
        tester_email = new_tester[:email]
        create_args_expect = { email: new_tester[:email], first_name: new_tester[:first_name], last_name: new_tester[:last_name], app_id: fake_apple_id }

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find_by_app).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find_by_app).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:create!).with(create_args_expect).and_return(new_tester)
        allow(new_tester).to receive(:add_to_app!).with(fake_apple_id).and_return(nil)

        expect(FastlaneCore::UI).to receive(:success).with(/Successfully invited tester: #{tester_email}/)
        expect(FastlaneCore::UI).to receive(:success).with(/Successfully added tester to app #{fake_apple_id}/)
        expect(new_tester).to receive(:add_to_app!)

        tester_manager.add_tester(app_identifier: 'com.whatever', email: tester_email, first_name: new_tester[:first_name], last_name: new_tester[:last_name])
      end

      it "fails to create a tester" do
        tester_email = new_tester[:email]
        create_args_expect = { email: new_tester[:email], first_name: new_tester[:first_name], last_name: new_tester[:last_name], app_id: fake_apple_id }

        allow(Spaceship::Tunes::Tester::Internal).to receive(:find_by_app).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:find_by_app).and_return(nil)
        allow(Spaceship::Tunes::Tester::External).to receive(:create!).with(create_args_expect).and_raise("failed_to_create")

        expect(FastlaneCore::UI).to receive(:error).with(/Could not create tester #{tester_email}/)

        expect do
          tester_manager.add_tester(app_identifier: 'com.whatever', email: tester_email, first_name: new_tester[:first_name], last_name: new_tester[:last_name])
        end.to raise_error("failed_to_create")
      end
    end
  end
end
