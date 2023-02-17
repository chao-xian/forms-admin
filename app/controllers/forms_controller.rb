class FormsController < ApplicationController
  include CheckFormOrganisation

  rescue_from ActiveResource::ResourceNotFound do
    render template: "errors/not_found", status: :not_found
  end

  def index
    @forms = Form.all(params: { org: @current_user.organisation_slug }) || []
  end

  def show
    @form = Form.find(params[:form_id])
    task_service = FormTaskListService.call(form: @form)
    @task_list = task_service.all_tasks
    @task_status_counts = task_service.task_counts
  end
end
