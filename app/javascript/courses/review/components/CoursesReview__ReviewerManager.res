open CoursesReview__Types
let str = React.string

let t = I18n.t(~scope="components.CoursesReview__ReviewerManager")

module AssignReviewerMutation = %graphql(
  `
    mutation AssignReviewerMutation($submissionId: ID!) {
      assignReviewer(submissionId: $submissionId){
        reviewer{
          id, userId, name, title, avatarUrl
        }
      }
    }
  `
)

module ReassignReviewerMutation = %graphql(
  `
    mutation ReassignReviewerMutation($submissionId: ID!) {
      reassignReviewer(submissionId: $submissionId){
        reviewer{
          id, userId, name, title, avatarUrl
        }
      }
    }
  `
)

let assignReviewer = (submissionId, setSaving, updateReviewerCB) => {
  setSaving(_ => true)
  AssignReviewerMutation.make(~submissionId, ())
  |> GraphqlQuery.sendQuery
  |> Js.Promise.then_(response => {
    updateReviewerCB(Some(Reviewer.makeFromJs(response["assignReviewer"]["reviewer"])))
    setSaving(_ => false)
    Js.Promise.resolve()
  })
  |> Js.Promise.catch(_ => {
    setSaving(_ => false)
    Js.Promise.resolve()
  })
  |> ignore
}

let reassignReviewer = (submissionId, setSaving, updateReviewerCB) => {
  setSaving(_ => true)
  ReassignReviewerMutation.make(~submissionId, ())
  |> GraphqlQuery.sendQuery
  |> Js.Promise.then_(response => {
    updateReviewerCB(Some(Reviewer.makeFromJs(response["reassignReviewer"]["reviewer"])))
    setSaving(_ => false)
    Js.Promise.resolve()
  })
  |> Js.Promise.catch(_ => {
    setSaving(_ => false)
    Js.Promise.resolve()
  })
  |> ignore
}

@react.component
let make = (~submissionId, ~submissionDetails, ~updateReviewerCB) => {
  let (saving, setSaving) = React.useState(_ => false)

  <div className="w-full p-4 md:p-6 space-y-8 mx-auto">
    <div>
      {switch SubmissionDetails.reviewer(submissionDetails) {
      | Some(reviewer) =>
        [
          <div className="text-xs text-gray-800"> {t("reviewer")->str} </div>,
          <div className="inline-flex bg-gray-200 px-3 py-2 mt-2 rounded-md">
            {switch Reviewer.avatarUrl(reviewer) {
            | Some(avatarUrl) =>
              <img
                className="h-9 w-9 md:h-10 md:w-10 text-xs border border-gray-400 rounded-full overflow-hidden flex-shrink-0 object-cover"
                src=avatarUrl
              />
            | None =>
              <Avatar
                name={Reviewer.name(reviewer)}
                className="h-9 w-9 md:h-10 md:w-10 text-xs border border-gray-400 rounded-full overflow-hidden flex-shrink-0 object-cover"
              />
            }}
            <div className="ml-2">
              <p className="text-sm font-semibold"> {Reviewer.name(reviewer)->str} </p>
              {switch SubmissionDetails.reviewerAssignedAt(submissionDetails) {
              | Some(date) =>
                <p className="text-xs text-gray-800">
                  {t(
                    ~variables=[("date", DateFns.formatDistanceToNow(date, ~addSuffix=true, ()))],
                    "assigned_at",
                  )->str}
                </p>
              | None => React.null
              }}
            </div>
          </div>,
        ]->React.array
      | None =>
        <div className="flex items-center justify-center">
          <div
            className="h-24 w-24 md:h-30 md:w-30 rounded-full bg-gray-300 flex items-center justify-center">
            <Icon className="if i-eye-solid text-gray-800 text-4xl" />
          </div>
        </div>
      }}
      <div className="mt-4">
        {Belt.Option.isSome(SubmissionDetails.reviewer(submissionDetails))
          ? <div className="flex flex-col md:flex-row items-center">
              <p className="text-sm pr-4"> {t("remove_reviewer_assign_to_me")->str} </p>
              <button
                disabled=saving
                onClick={_ => reassignReviewer(submissionId, setSaving, updateReviewerCB)}
                className="btn md:btn-small btn-default w-full md:w-auto mt-2 md:mt-0">
                {str(t("change_reviewer_and_start_review"))}
              </button>
            </div>
          : <div className="flex items-center justify-center">
              <button
                disabled=saving
                onClick={_ => assignReviewer(submissionId, setSaving, updateReviewerCB)}
                className="btn btn-primary w-full md:w-auto">
                {str(t("start_review"))}
              </button>
            </div>}
      </div>
    </div>
  </div>
}
