require 'rails_helper'

feature 'Submissions show' do
  include UserSpecHelper
  include MarkdownEditorHelper
  include NotificationHelper

  let(:school) { create :school, :current }
  let(:course) { create :course, school: school }
  let(:level) { create :level, :one, course: course }
  let(:target_group) { create :target_group, level: level }
  let(:target) { create :target, :for_founders, target_group: target_group }
  let(:auto_verify_target) { create :target, :for_founders, target_group: target_group }
  let(:evaluation_criterion_1) { create :evaluation_criterion, course: course }
  let(:evaluation_criterion_2) { create :evaluation_criterion, course: course }

  let(:team) { create :startup, level: level }
  let(:coach) { create :faculty, school: school }
  let(:team_coach) { create :faculty, school: school }
  let(:school_admin) { create :school_admin }

  before do
    create :faculty_course_enrollment, faculty: coach, course: course
    create :faculty_startup_enrollment, faculty: team_coach, startup: team

    # Set evaluation criteria on the target so that its submissions can be reviewed.
    target.evaluation_criteria << [evaluation_criterion_1, evaluation_criterion_2]
  end

  context 'with a pending submission' do
    let(:submission_pending) { create(:timeline_event, latest: true, target: target) }
    before do
      submission_pending.founders << team.founders.first
    end

    scenario 'coach visits submission show', js: true do
      sign_in_user coach.user, referer: timeline_event_path(submission_pending)

      within("div[aria-label='submissions-overlay-header']") do
        expect(page).to have_content('Level 1')
        expect(page).to have_content("Submitted by #{team.founders.first.user.name}")
        expect(page).to have_link("View Target", href: "/targets/#{target.id}")
        expect(page).to have_content(target.title)
      end
      expect(page).to have_content('Add Your Feedback')
      expect(page).to have_content('Grade Card')
      expect(page).to have_content(evaluation_criterion_1.name)
      expect(page).to have_content(evaluation_criterion_2.name)
      expect(page).to have_button("Save grades", disabled: true)
    end

    scenario 'coach evaluates a pending submission and gives a feedback', js: true do
      sign_in_user coach.user, referer: timeline_event_path(submission_pending)

      feedback = Faker::Markdown.sandwich(6)
      add_markdown(feedback)
      expect(page).to have_content('Grade Card')

      within("div[aria-label='evaluation-criterion-#{evaluation_criterion_1.id}']") do
        find("div[title='Bad']").click
      end

      # status should be reviewing as the target is not graded completely
      within("div[aria-label='submission-status']") do
        expect(page).to have_text('Reviewing')
      end
      within("div[aria-label='evaluation-criterion-#{evaluation_criterion_2.id}']") do
        find("div[title='Bad']").click
      end

      # the status should be failed
      within("div[aria-label='submission-status']") do
        expect(page).to have_text('Failed')
      end

      within("div[aria-label='evaluation-criterion-#{evaluation_criterion_2.id}']") do
        find("div[title='Good']").click
      end

      # the status should be failed
      within("div[aria-label='submission-status']") do
        expect(page).to have_text('Failed')
      end

      click_button 'Save grades & send feedback'

      dismiss_notification

      expect(page).to have_button('Undo Grading')

      submission = submission_pending.reload
      expect(submission.evaluator_id).to eq(coach.id)
      expect(submission.passed_at).to eq(nil)
      expect(submission.evaluated_at).not_to eq(nil)
      expect(submission.startup_feedback.count).to eq(1)
      expect(submission.startup_feedback.last.feedback).to eq(feedback)
      expect(submission.timeline_event_grades.pluck(:grade)).to eq([1, 2])
    end

    scenario 'coach evaluates a pending submission without giving a feedback', js: true do
      sign_in_user coach.user, referer: timeline_event_path(submission_pending)

      expect(page).to have_content('Grade Card')

      within("div[aria-label='evaluation-criterion-#{evaluation_criterion_1.id}']") do
        find("div[title='Good']").click
      end

      # status should be reviewing as the target is not graded completely
      within("div[aria-label='submission-status']") do
        expect(page).to have_text('Reviewing')
      end
      within("div[aria-label='evaluation-criterion-#{evaluation_criterion_2.id}']") do
        find("div[title='Good']").click
      end

      # the status should be failed
      within("div[aria-label='submission-status']") do
        expect(page).to have_text('Passed')
      end

      click_button 'Save grades'

      dismiss_notification

      expect(page).to have_button('Undo Grading')

      submission = submission_pending.reload
      expect(submission.evaluator_id).to eq(coach.id)
      expect(submission.passed_at).not_to eq(nil)
      expect(submission.evaluated_at).not_to eq(nil)
      expect(submission.startup_feedback.count).to eq(0)
      expect(submission.timeline_event_grades.pluck(:grade)).to eq([2, 2])
    end

    scenario 'student tries to access the submission show' do
      sign_in_user team.founders.first.user, referer: timeline_event_path(submission_pending)

      expect(page).to have_text("The page you were looking for doesn't exist!")
    end

    scenario 'school admin tries to access the submission show' do
      sign_in_user school_admin.user, referer: timeline_event_path(submission_pending)

      expect(page).to have_text("The page you were looking for doesn't exist!")
    end
  end

  context 'with a reviewed submission' do
    let(:submission_reviewed) { create(:timeline_event, latest: true, target: target, evaluator_id: coach.id, evaluated_at: 1.day.ago, passed_at: 1.day.ago) }
    let!(:timeline_event_grade) { create(:timeline_event_grade, timeline_event: submission_reviewed, evaluation_criterion: evaluation_criterion_1) }
    before do
      submission_reviewed.founders << team.founders.first
    end

    scenario 'coach visits submission show', js: true do
      sign_in_user coach.user, referer: timeline_event_path(submission_reviewed)

      within("div[aria-label='submissions-overlay-header']") do
        expect(page).to have_content('Level 1')
        expect(page).to have_content("Submitted by #{team.founders.first.user.name}")
        expect(page).to have_link("View Target", href: "/targets/#{target.id}")
        expect(page).to have_content(target.title)
      end
      expect(page).to have_content('Submission #1')
      expect(page).to have_content('Passed')

      within("div[aria-label='submission-status']") do
        expect(page).to have_text('Passed')
        expect(page).to have_text('Evaluated By')
        expect(page).to have_text(coach.name)
        expect(page).to have_button("Undo Grading")
      end

      within("div[aria-label='evaluation-criterion-#{evaluation_criterion_1.id}']") do
        expect(page).to have_text(evaluation_criterion_1.name)
        expect(page).to have_text("#{timeline_event_grade.grade}/#{course.max_grade}")
      end

      expect(page).to have_button("Add feedback")
    end

    scenario 'coach add his feedback', js: true do
      sign_in_user coach.user, referer: timeline_event_path(submission_reviewed)

      within("div[aria-label='submission-status']") do
        expect(page).to have_text('Passed')
        expect(page).to have_text('Evaluated By')
        expect(page).to have_text(coach.name)
        expect(page).to have_button("Undo Grading")
      end
      expect(page).to have_button("Add feedback")
      click_button "Add feedback"
      expect(page).not_to have_button("Add feedback")
      expect(page).to have_button("Share Feedback", disabled: true)

      feedback = Faker::Markdown.sandwich(6)
      add_markdown(feedback)
      click_button "Share Feedback"

      dismiss_notification

      expect(page).to have_button('Add another feedback')

      within("div[aria-label='feedback-section']") do
        expect(page).to have_text(coach.name)
      end
      submission = submission_reviewed.reload
      expect(submission.startup_feedback.count).to eq(1)
      expect(submission.startup_feedback.last.feedback).to eq(feedback)
    end

    scenario 'coach can undo grading', js: true do
      sign_in_user coach.user, referer: timeline_event_path(submission_reviewed)

      within("div[aria-label='submission-status']") do
        expect(page).to have_text('Passed')
        expect(page).to have_text('Evaluated By')
        expect(page).to have_text(coach.name)
        expect(page).to have_button("Undo Grading")
      end
      click_button "Undo Grading"

      expect(page).to have_text("Add Your Feedback")

      submission = submission_reviewed.reload
      expect(submission.evaluator_id).to eq(nil)
      expect(submission.passed_at).to eq(nil)
      expect(submission.evaluated_at).to eq(nil)
      expect(submission.timeline_event_grades).to eq([])
    end
  end

  context 'with a reviewed submission that has feedback' do
    let(:submission_reviewed) { create(:timeline_event, latest: true, target: target, evaluator_id: coach.id, evaluated_at: 1.day.ago, passed_at: 1.day.ago) }
    let(:feedback) { create(:startup_feedback, startup_id: team.id, faculty_id: coach.id) }
    let!(:timeline_event_grade) { create(:timeline_event_grade, timeline_event: submission_reviewed, evaluation_criterion: evaluation_criterion_1) }
    before do
      submission_reviewed.founders << team.founders.first
      submission_reviewed.startup_feedback << feedback
    end

    scenario 'team coach add his feedback', js: true do
      sign_in_user team_coach.user, referer: timeline_event_path(submission_reviewed)
      within("div[aria-label='submission-status']") do
        expect(page).to have_text('Passed')
        expect(page).to have_text('Evaluated By')
        expect(page).to have_text(coach.name)
        expect(page).to have_button("Undo Grading")
      end
      within("div[aria-label='feedback-section']") do
        expect(page).to have_text(coach.name)
      end

      expect(page).to have_button("Add another feedback")
      click_button "Add another feedback"
      expect(page).not_to have_button("Add feedback")
      expect(page).to have_button("Share Feedback", disabled: true)

      feedback = Faker::Markdown.sandwich(6)
      add_markdown(feedback)
      click_button "Share Feedback"

      dismiss_notification

      expect(page).to have_button('Add another feedback')

      submission = submission_reviewed.reload
      expect(submission.startup_feedback.count).to eq(2)
      expect(submission.startup_feedback.last.feedback).to eq(feedback)
    end

    scenario 'team coach undo submission', js: true do
      sign_in_user team_coach.user, referer: timeline_event_path(submission_reviewed)

      within("div[aria-label='submission-status']") do
        expect(page).to have_text('Passed')
        expect(page).to have_text('Evaluated By')
        expect(page).to have_text(coach.name)
        expect(page).to have_button("Undo Grading")
      end
      click_button "Undo Grading"

      expect(page).to have_text("Add Your Feedback")

      submission = submission_reviewed.reload
      expect(submission.evaluator_id).to eq(nil)
      expect(submission.passed_at).to eq(nil)
      expect(submission.evaluated_at).to eq(nil)
      expect(submission.timeline_event_grades).to eq([])
    end
  end

  context 'with a auto verified submission' do
    let(:auto_verified_submission) { create(:timeline_event, latest: true, target: auto_verify_target, passed_at: 1.day.ago) }
    before do
      auto_verified_submission.founders << team.founders.first
    end

    scenario 'coach visits submission show' do
      sign_in_user team_coach.user, referer: timeline_event_path(auto_verified_submission)

      expect(page).to have_text("The page you were looking for doesn't exist!")
    end
  end
end
