describe AssignmentsController do
  # copied from the controller
  DEFAULT_FIELDS = [:short_identifier, :description,
                    :due_date, :message, :group_min, :group_max,
                    :tokens_per_period, :allow_web_submits,
                    :student_form_groups, :remark_due_date,
                    :remark_message, :assign_graders_to_criteria,
                    :enable_test, :enable_student_tests, :allow_remarks,
                    :display_grader_names_to_students,
                    :display_median_to_students, :group_name_autogenerated,
                    :is_hidden, :vcs_submit, :has_peer_review].freeze

  let(:annotation_category) { FactoryBot.create(:annotation_category) }

  let(:example_form_params) do
    {
      is_group_assignment: true,
      is_hidden: 0,
      assignment: {
        assignment_properties_attributes: {
          scanned_exam: false, section_due_dates_type: 0, allow_web_submits: 0, vcs_submit: 0,
          display_median_to_students: 0, display_grader_names_to_students: 0, has_peer_review: 0,
          student_form_groups: 0, group_min: 1, group_max: 1, group_name_autogenerated: 1, allow_remarks: 0
        },
        submission_rule_attributes: {
          type: 'PenaltyDecayPeriodSubmissionRule',
          periods_attributes: { 999 => { deduction: 10.0, interval: 1.0, hours: 10.0, _destroy: 0, id: nil } }
        },
        description: 'Test',
        message: '',
        due_date: Time.now.to_s
      }
    }
  end

  context '#upload' do
    before :each do
      # Authenticate user is not timed out, and has administrator rights.
      allow(controller).to receive(:session_expired?).and_return(false)
      allow(controller).to receive(:logged_in?).and_return(true)
      allow(controller).to receive(:current_user).and_return(build(:admin))
    end

    include_examples 'a controller supporting upload' do
      let(:params) { {} }
    end

    before :each do
      # We need to mock the rack file to return its content when
      # the '.read' method is called to simulate the behaviour of
      # the http uploaded file
      @file_good = fixture_file_upload('files/assignments/form_good.csv', 'text/csv')
      allow(@file_good).to receive(:read).and_return(
        File.read(fixture_file_upload('files/assignments/form_good.csv', 'text/csv'))
      )
      @file_good_yml = fixture_file_upload('files/assignments/form_good.yml', 'text/yaml')
      allow(@file_good_yml).to receive(:read).and_return(
        File.read(fixture_file_upload('files/assignments/form_good.yml', 'text/yaml'))
      )

      @file_invalid_column = fixture_file_upload('files/assignments/form_invalid_column.csv', 'text/csv')
      allow(@file_invalid_column).to receive(:read).and_return(
        File.read(fixture_file_upload('files/assignments/form_invalid_column.csv', 'text/csv'))
      )

      # This must line up with the second entry in the file_good
      @test_asn1 = 'ATest1'
      @test_asn2 = 'ATest2'
    end

    it 'accepts a valid file' do
      post :upload, params: { upload_file: @file_good }

      expect(response.status).to eq(302)
      test1 = Assignment.find_by(short_identifier: @test_asn1)
      expect(test1).to_not be_nil
      test2 = Assignment.find_by(short_identifier: @test_asn2)
      expect(test2).to_not be_nil
      expect(flash[:error]).to be_nil
      expect(flash[:success].map { |f| extract_text f }).to eq([I18n.t('upload_success',
                                                                       count: 2)].map { |f| extract_text f })
      expect(response).to redirect_to(action: 'index',
                                      controller: 'assignments')
    end

    it 'accepts a valid YAML file' do
      post :upload, params: { upload_file: @file_good_yml }

      expect(response.status).to eq(302)
      test1 = Assignment.find_by_short_identifier(@test_asn1)
      expect(test1).to_not be_nil
      test2 = Assignment.find_by_short_identifier(@test_asn2)
      expect(test2).to_not be_nil
      expect(flash[:error]).to be_nil
      expect(response).to redirect_to(action: 'index', controller: 'assignments')
    end

    it 'does not accept files with invalid columns' do
      post :upload, params: { upload_file: @file_invalid_column }

      expect(response.status).to eq(302)
      expect(flash[:error]).to_not be_empty
      test = Assignment.find_by_short_identifier(@test_asn2)
      expect(test).to be_nil
      expect(response).to redirect_to(action: 'index',
                                      controller: 'assignments')
    end
  end

  context 'CSV_Downloads' do
    before :each do
      # Authenticate user is not timed out, and has administrator rights.
      allow(controller).to receive(:session_expired?).and_return(false)
      allow(controller).to receive(:logged_in?).and_return(true)
      allow(controller).to receive(:current_user).and_return(build(:admin))
    end

    let(:csv_options) do
      { type: 'text/csv', filename: 'assignments.csv', disposition: 'attachment' }
    end
    let!(:assignment) { create(:assignment) }

    it 'responds with appropriate status' do
      get :download, params: { format: 'csv' }
      expect(response.status).to eq(200)
    end

    # parse header object to check for the right disposition
    it 'sets disposition as attachment' do
      get :download, params: { format: 'csv' }
      d = response.header['Content-Disposition'].split.first
      expect(d).to eq 'attachment;'
    end

    it 'expects a call to send_data' do
      # generate the expected csv string
      csv_data = []
      DEFAULT_FIELDS.map do |f|
        csv_data << assignment.send(f)
      end
      new_data = csv_data.join(',') + "\n"
      expect(@controller).to receive(:send_data).with(new_data, csv_options) {
        # to prevent a 'missing template' error
        @controller.head :ok
      }
      get :download, params: { format: 'csv' }
    end

    # parse header object to check for the right content type
    it 'returns text/csv type' do
      get :download, params: { format: 'csv' }
      expect(response.media_type).to eq 'text/csv'
    end

    # parse header object to check for the right file naming convention
    it 'filename passes naming conventions' do
      get :download, params: { format: 'csv' }
      filename = response.header['Content-Disposition'].split[1].split('"').second
      expect(filename).to eq 'assignments.csv'
    end
  end

  context 'YML_Downloads' do
    let(:yml_options) do
      { type: 'text/yml', filename: 'assignments.yml', disposition: 'attachment' }
    end
    let!(:assignment) { create(:assignment) }

    before :each do
      # Authenticate user is not timed out, and has administrator rights.
      allow(controller).to receive(:session_expired?).and_return(false)
      allow(controller).to receive(:logged_in?).and_return(true)
      allow(controller).to receive(:current_user).and_return(build(:admin))
    end

    it 'responds with appropriate status' do
      get :download, params: { format: 'yml' }
      expect(response.status).to eq(200)
    end

    # parse header object to check for the right disposition
    it 'sets disposition as attachment' do
      get :download, params: { format: 'yml' }
      d = response.header['Content-Disposition'].split.first
      expect(d).to eq 'attachment;'
    end

    it 'expects a call to send_data' do
      # generate the expected yml string
      assignments = Assignment.all
      map = {}
      map[:assignments] = assignments.map do |assignment|
        m = {}
        DEFAULT_FIELDS.each do |f|
          m[f] = assignment.send(f)
        end
        m
      end
      map = map.to_yaml
      expect(@controller).to receive(:send_data).with(map, yml_options) {
        # to prevent a 'missing template' error
        @controller.head :ok
      }
      get :download, params: { format: 'yml' }
    end

    # parse header object to check for the right content type
    it 'returns text/yml type' do
      get :download, params: { format: 'yml' }
      expect(response.media_type).to eq 'text/yml'
    end

    # parse header object to check for the right file naming convention
    it 'filename passes naming conventions' do
      get :download, params: { format: 'yml' }
      filename = response.header['Content-Disposition'].split[1].split('"').second
      expect(filename).to eq 'assignments.yml'
    end
  end

  describe '#index' do
    context 'an admin' do
      let(:user) { create(:admin) }

      context 'when there are no assessments' do
        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end

      context 'where there are some assessments' do
        before :each do
          3.times { create(:assignment_with_criteria_and_results) }
          2.times { create(:grade_entry_form_with_data) }
        end

        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end
    end

    context 'a TA' do
      let(:user) { create(:ta) }

      context 'when there are no assessments' do
        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end

      context 'where there are some assessments' do
        before :each do
          3.times { create(:assignment_with_criteria_and_results) }
          2.times { create(:grade_entry_form_with_data) }
        end

        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end
    end

    context 'a student' do
      let(:user) { create(:student) }

      context 'when there are no assessments' do
        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end

      context 'where there are some assessments' do
        before :each do
          3.times do
            assignment = create(:assignment_with_criteria_and_results)
            create(:accepted_student_membership, user: user, grouping: assignment.groupings.first)
          end
          2.times { create(:grade_entry_form_with_data) }
        end

        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end

      context 'where there are some assessments, including hidden assessments' do
        before :each do
          3.times do
            assignment = create(:assignment_with_criteria_and_results)
            create(:accepted_student_membership, user: user, grouping: assignment.groupings.first)
          end
          2.times { create(:grade_entry_form_with_data) }
          Assignment.first.update(is_hidden: true)
          GradeEntryForm.first.update(is_hidden: true)
        end

        it 'responds with a success' do
          get_as user, :index
          assert_response :success
        end
      end
    end
  end

  context '#set_boolean_graders_options' do
    let!(:assignment) { create(:assignment) }
    context 'an admin' do
      let(:user) { create :admin }
      let(:value) { !assignment.assignment_properties[attribute] }

      before :each do
        post_as user, :set_boolean_graders_options,
                params: { id: assignment.id,
                          attribute: { assignment_properties_attributes: { attribute => value } } }
        assignment.reload
      end

      shared_examples 'successful tests' do
        it 'should respond with 200' do
          expect(response.status).to eq(200)
        end
        it 'should update the attribute' do
          expect(assignment.assignment_properties[attribute]).to eq(value)
        end
      end

      context 'with a valid attribute field' do
        context 'is assign_graders_to_criteria' do
          let(:attribute) { :assign_graders_to_criteria }
          it_behaves_like 'successful tests'
        end
        context 'is anonymize_groups' do
          let(:attribute) { :anonymize_groups }
          it_behaves_like 'successful tests'
        end
        context 'is hide_unassigned_criteria' do
          let(:attribute) { :hide_unassigned_criteria }
          it_behaves_like 'successful tests'
        end
      end

      context 'with an invalid attribute field' do
        let(:attribute) { :this_is_not_a_real_attribute }
        let(:value) { true }
        it 'should respond with 400' do
          expect(response.status).to eq(400)
        end
      end
    end
  end

  describe '#show' do
    let!(:assignment) { create(:assignment) }
    let!(:user) { create(:student) }

    xcontext 'when the assignment is an individual assignment' do
      it 'responds with a success and creates a new grouping' do
        assignment.update!(group_min: 1, group_max: 1)
        post_as user, :show, params: { id: assignment.id }
        assert_response :success
        expect(user.student_memberships.size).to eq 1
        expect(user.groupings.first.assignment_id).to eq assignment.id
      end
    end

    xcontext 'when the assignment is a group assignment and the student belongs to a group' do
      it 'responds with a success' do
        assignment.update!(group_min: 1, group_max: 3)
        grouping = create(:grouping_with_inviter, assignment: assignment)
        post_as grouping.inviter, :show, params: { id: assignment.id }
        assert_response :success
      end
    end

    context 'when the assignment is a group assignment and the student does not belong to a group' do
      it 'responds with a success and does not create a grouping' do
        assignment.update!(group_min: 1, group_max: 3)
        post_as user, :show, params: { id: assignment.id }
        assert_response :success

        expect(user.groupings.size).to eq 0
      end
    end

    context 'when the assignment is hidden' do
      it 'responds with a not_found status' do
        assignment.update!(is_hidden: true)
        post_as user, :show, params: { id: assignment.id }
        assert_response :not_found
      end
    end
  end

  describe '#summary' do
    let!(:assignment) { create(:assignment) }

    context 'when an admin' do
      let!(:user) { create(:admin) }
      context 'requests an HTML response' do
        it 'responds with a success' do
          post_as user, :summary, params: { id: assignment.id }, format: 'html'
          assert_response :success
        end
      end

      context 'requests a JSON response' do
        before do
          post_as user, :summary, params: { id: assignment.id }, format: 'json'
        end
        it 'responds with a success' do
          assert_response :success
        end

        it 'responds with the correct keys' do
          expect(response.parsed_body.keys.to_set).to eq Set[
            'data', 'criteriaColumns', 'numAssigned', 'numMarked'
          ]
        end
      end

      context 'requests a CSV response' do
        before do
          post_as user, :summary, params: { id: assignment.id }, format: 'csv'
        end
        it 'responds with a success' do
          assert_response :success
        end
      end
    end
  end

  context '#new' do
    context 'as an admin' do
      shared_examples 'assignment_new_success' do
        it 'responds with a success' do
          expect(response).to have_http_status :success
        end
        it 'renders the new template' do
          expect(response).to render_template(:new)
        end
      end
      let(:user) { create :admin }
      context 'when the assignment is a scanned assignment' do
        before do
          get_as user, :new, params: { scanned: true }
        end
        it_behaves_like 'assignment_new_success'
        it 'assigns @assignment as a scanned assignment' do
          expect(assigns(:assignment).scanned_exam).to eq true
        end
        it 'does not assign @assignment as a timed assignment' do
          expect(assigns(:assignment).is_timed).to eq false
        end
      end
      context 'when the assignment is a timed assignment' do
        before do
          get_as user, :new, params: { timed: true }
        end
        it_behaves_like 'assignment_new_success'
        it 'assigns @assignment as a timed assignment' do
          expect(assigns(:assignment).is_timed).to eq true
        end
        it 'does not assign @assignment as a scanned assignment' do
          expect(assigns(:assignment).scanned_exam).to eq false
        end
      end
      context 'when the assignment is a regular assignment' do
        before do
          get_as user, :new, params: {}
        end
        it_behaves_like 'assignment_new_success'
        it 'does not assign @assignment as a timed assignment' do
          expect(assigns(:assignment).is_timed).to eq false
        end
        it 'does not assign @assignment as a scanned assignment' do
          expect(assigns(:assignment).scanned_exam).to eq false
        end
      end
    end
    context 'as a grader' do
      it 'should respond with 404' do
        get_as create(:ta), :new, params: {}
        expect(response).to have_http_status 404
      end
    end
    context 'as a student' do
      it 'should respond with 404' do
        get_as create(:student), :new, params: {}
        expect(response).to have_http_status 404
      end
    end
  end

  context '#start_timed_assignment' do
    let(:assignment) { create :timed_assignment }
    context 'as a student' do
      let(:user) { create :student }
      context 'when a grouping exists' do
        let!(:grouping) { create :grouping_with_inviter, assignment: assignment, start_time: nil, inviter: user }
        it 'should respond with 302' do
          put_as user, :start_timed_assignment, params: { id: assignment.id }
          expect(response).to have_http_status :redirect
        end
        it 'should redirect to show' do
          put_as user, :start_timed_assignment, params: { id: assignment.id }
          expect(response).to redirect_to(action: :show)
        end
        it 'should update the start_time' do
          put_as user, :start_timed_assignment, params: { id: assignment.id }
          expect(grouping.reload.start_time).to be_within(5.seconds).of(Time.current)
        end
        context 'a validation fails' do
          it 'should flash an error message' do
            allow_any_instance_of(Grouping).to receive(:update).and_return false
            put_as user, :start_timed_assignment, params: { id: assignment.id }
            expect(flash[:error]).not_to be_nil
          end
        end
      end
      context 'when a grouping does not exist' do
        it 'should respond with 400' do
          put_as user, :start_timed_assignment, params: { id: assignment.id }
          expect(response).to have_http_status 400
        end
      end
    end
    context 'as an admin' do
      let(:user) { create :admin }
      it 'should respond with 400' do
        put_as user, :start_timed_assignment, params: { id: assignment.id }
        expect(response).to have_http_status 400
      end
    end
    context 'as an grader' do
      let(:user) { create :ta }
      it 'should respond with 400' do
        put_as user, :start_timed_assignment, params: { id: assignment.id }
        expect(response).to have_http_status 400
      end
    end
  end

  context '#create' do
    let(:params) { example_form_params }
    context 'as an admin' do
      let(:admin) { create :admin }
      it 'should create an assignment without errors' do
        post_as admin, :create, params: params
      end
      it 'should respond with 200' do
        post_as admin, :create, params: params
        expect(response).to have_http_status 200
      end
      shared_examples 'create assignment_properties' do |property, after|
        it "should create #{property}" do
          params[:assignment][:assignment_properties_attributes][property] = after
          post_as admin, :create, params: params
          expect(assigns(:assignment).assignment_properties[property]).to eq after
        end
      end
      shared_examples 'create assignment' do |property, after|
        it "should create #{property}" do
          params[:assignment][property] = after
          post_as admin, :create, params: params
          expect(assigns(:assignment)[property]).to eq after
        end
      end
      it_behaves_like 'create assignment_properties', :section_due_dates_type, true
      it_behaves_like 'create assignment_properties', :allow_web_submits, true
      it_behaves_like 'create assignment_properties', :vcs_submit, true
      it_behaves_like 'create assignment_properties', :display_median_to_students, true
      it_behaves_like 'create assignment_properties', :display_grader_names_to_students, true
      it_behaves_like 'create assignment_properties', :has_peer_review, true
      it_behaves_like 'create assignment_properties', :student_form_groups, true
      it_behaves_like 'create assignment_properties', :group_name_autogenerated, true
      it_behaves_like 'create assignment_properties', :allow_remarks, true
      it_behaves_like 'create assignment_properties', :group_min, 2
      it_behaves_like 'create assignment_properties', :group_min, 3
      it_behaves_like 'create assignment', :description, 'BBB'
      it_behaves_like 'create assignment', :message, 'BBB'
      it_behaves_like 'create assignment', :due_date, (Time.now - 1.hour).to_s
      it 'should set duration when this is a timed assignment' do
        params[:assignment][:assignment_properties_attributes][:duration] = { hours: 2, minutes: 20 }
        params[:assignment][:assignment_properties_attributes][:start_time] = Time.now - 10.hours
        params[:assignment][:assignment_properties_attributes][:is_timed] = true
        post_as admin, :create, params: params
        expect(assigns(:assignment).duration).to eq(2.hours + 20.minutes)
      end
      it 'should not set duration when this is a not a timed assignment' do
        params[:assignment][:assignment_properties_attributes][:duration] = { hours: 2, minutes: 20 }
        params[:assignment][:assignment_properties_attributes][:start_time] = Time.now - 10.hours
        params[:assignment][:assignment_properties_attributes][:is_timed] = false
        post_as admin, :create, params: params
        expect(assigns(:assignment).duration).to eq nil
      end
    end
    context 'as a student' do
      let(:user) { create :student }
      it 'should respond with 404' do
        post_as user, :create, params: params
        expect(response).to have_http_status 404
      end
    end
    context 'as an grader' do
      let(:user) { create :ta }
      it 'should respond with 404' do
        post_as user, :create, params: params
        expect(response).to have_http_status 404
      end
    end
  end

  context '#update' do
    let(:assignment) { create :assignment }
    let(:submission_rule) { create :penalty_decay_period_submission_rule, assignment: assignment }
    let(:params) do
      example_form_params[:id] = assignment.id
      example_form_params[:assignment][:assignment_properties_attributes][:id] = assignment.id
      example_form_params[:assignment][:short_identifier] = assignment.short_identifier
      example_form_params[:assignment][:submission_rule_attributes][:periods_attributes] = submission_rule.id
      example_form_params
    end
    context 'as an admin' do
      let(:admin) { create :admin }
      it 'should update an assignment without errors' do
        patch_as admin, :update, params: params
      end
      shared_examples 'update assignment_properties' do |property, before, after|
        it "should update #{property}" do
          assignment.update!(property => before)
          params[:assignment][:assignment_properties_attributes][property] = after
          patch_as admin, :update, params: params
          expect(assignment.reload.assignment_properties[property]).to eq after
        end
      end
      shared_examples 'update assignment' do |property, before, after|
        it "should update #{property}" do
          assignment.update!(property => before)
          params[:assignment][property] = after
          patch_as admin, :update, params: params
          expect(assignment.reload[property]).to eq after
        end
      end
      it_behaves_like 'update assignment_properties', :section_due_dates_type, false, true
      it_behaves_like 'update assignment_properties', :allow_web_submits, false, true
      it_behaves_like 'update assignment_properties', :vcs_submit, false, true
      it_behaves_like 'update assignment_properties', :display_median_to_students, false, true
      it_behaves_like 'update assignment_properties', :display_grader_names_to_students, false, true
      it_behaves_like 'update assignment_properties', :has_peer_review, false, true
      it_behaves_like 'update assignment_properties', :student_form_groups, false, true
      it_behaves_like 'update assignment_properties', :group_name_autogenerated, false, true
      it_behaves_like 'update assignment_properties', :allow_remarks, false, true
      it_behaves_like 'update assignment', :description, 'AAA', 'BBB'
      it_behaves_like 'update assignment', :message, 'AAA', 'BBB'
      it_behaves_like 'update assignment', :due_date, Time.now.to_s, (Time.now - 1.hour).to_s
      it 'should update group_min and group_max when is_group_assignment is true' do
        assignment.update!(group_min: 1, group_max: 1)
        params[:assignment][:assignment_properties_attributes][:group_min] = 2
        params[:assignment][:assignment_properties_attributes][:group_max] = 3
        params[:is_group_assignment] = true
        patch_as admin, :update, params: params
        assignment.reload
        expect(assignment.assignment_properties[:group_min]).to eq 2
        expect(assignment.assignment_properties[:group_max]).to eq 3
      end
      it 'should not update group_min and group_max when is_group_assignment is false' do
        assignment.update!(group_min: 1, group_max: 1)
        params[:assignment][:assignment_properties_attributes][:group_min] = 2
        params[:assignment][:assignment_properties_attributes][:group_max] = 3
        params[:is_group_assignment] = false
        patch_as admin, :update, params: params
        assignment.reload
        expect(assignment.assignment_properties[:group_min]).to eq 1
        expect(assignment.assignment_properties[:group_max]).to eq 1
      end
      it 'should update duration when this is a timed assignment' do
        assignment.update!(is_timed: true, start_time: Time.now - 10.hours, duration: 10.minutes)
        params[:assignment][:assignment_properties_attributes][:duration] = { hours: 2, minutes: 20 }
        patch_as admin, :update, params: params
        expect(assignment.reload.duration).to eq(2.hours + 20.minutes)
      end
      it 'should not update duration when this is a not a timed assignment' do
        assignment.update!(is_timed: false)
        params[:assignment][:assignment_properties_attributes][:duration] = { hours: 2, minutes: 20 }
        patch_as admin, :update, params: params
        expect(assignment.reload.duration).to eq nil
      end
    end
    context 'as a student' do
      let(:user) { create :student }
      it 'should respond with 404' do
        patch_as user, :update, params: params
        expect(response).to have_http_status 404
      end
    end
    context 'as an grader' do
      let(:user) { create :ta }
      it 'should respond with 404' do
        patch_as user, :update, params: params
        expect(response).to have_http_status 404
      end
    end
  end
end
