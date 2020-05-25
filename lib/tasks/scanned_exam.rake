namespace :db do
  desc 'Create a populated exam template assignment'
  task scanned_exam: :environment do
    puts 'Assignment 5: Scanned Exam'

    # remove previously existing pdfs to create room for new ones
    FileUtils.rm_rf(Dir.glob('data/dev/exam_templates/*'))

    a = Assignment.create(
      short_identifier: 'midterm',
      description: 'The first midterm',
      message: 'Illustrates the use of scanned exams.',
      due_date: 1.minute.from_now,
      assignment_properties_attributes: {
        group_name_autogenerated: false,
        repository_folder: 'midterm',
        allow_remarks: true,
        remark_due_date: 7.days.from_now,
        token_start_date: Time.current,
        token_period: 1,
        scanned_exam: true
      },
    )

    # For a description of the seed files, see db/data/scanned_exams/README.md.
    file_dir  = File.join(File.dirname(__FILE__), '/../../db/data/scanned_exams')
    f = File.open(File.join(file_dir, 'midterm1-v2-test.pdf'))
    template = ExamTemplate.create_with_file(f.read, assessment_id: a.id, filename: 'midterm1-v2-test.pdf')
    template.template_divisions.create(label: 'Q1', start: 3, end: 3)
    template.template_divisions.create(label: 'Q2', start: 4, end: 4)
    template.template_divisions.create(label: 'Q3', start: 5, end: 6)

    admin = Admin.first

    %w(1-20 100 101 102 103 104).each do |n|
      template_path = File.join(file_dir, "midterm_scan_#{n}.pdf")
      template.split_pdf(template_path, "midterm_scan_#{n}.pdf", admin)
    end
  end
end
