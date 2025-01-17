class ApplicantMailer < SchoolMailer
  def enrollment_verification(applicant)
    @applicant = applicant
    @school = applicant.course.school

    simple_mail(@applicant.email, I18n.t("mailers.applicant.verify"), enable_reply: false)
  end
end
