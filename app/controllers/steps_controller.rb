class StepsController < ApplicationController

  before_action :set_steps_list
  before_action :set_step, only: [:init, :show]
  before_action :set_candidate, only: [:show]

  skip_before_action :authenticate_user!

  def init
     @candidate = Candidate.new
  end

  def show
    customize_step
  end

  # def register_candidates
  #   if user_signed_in?
  #     session['candidates'].each do |candidate_id|
  #       candidate = Candidate.find(candidate_id)
  #       candidate.user_id = current_user.id
  #       candidate.save
  #     end
  #   end
  #   redirect(dashboard_index_path)
  # end


  def next
    # TODO : avoid that user changes the GET value
    # TODO : allow only permit data
    # => in this case goto current_user passed step instead
    # TODO: securité limiter au méthodes setter attendues
    # TODO: avoid loading each time ?
    # TODO: secure inputs

    next_step = params['next']

    # PERSIST CANDIDATE IN OBJECT OR SESSION

    # save input in session
    unless session['current_candidate']
      session['candidate'] = Hash.new unless session['candidate']
      params[:candidate].each do |param|
        session['candidate'][param[0]] = param[1]
      end
    end

   # persist input in current candidate
    if session['current_candidate']
      candidate = Candidate.find(session['current_candidate'])
      params['candidate'].each do |param|
        candidate.send("#{param[0]}=", param[1])
        candidate.performed_step = next_step
      end
      candidate.save
    else
      # init des candidates
      if params[:persist]
        candidates_id = []
        session['candidate']['dossier_people'].to_i.times do
          # construire le candidate
          candidate = Candidate.new
          session['candidate'].each do |attribute|
            candidate.send("#{attribute[0]}=", attribute[1])
          end
          candidate.biographie = candidate.intro
          candidate.save
          candidates_id << candidate.id
        end
        reset_session # flush session
        session['candidates'] = candidates_id
        session['current_candidate'] = candidates_id.first
      end
    end

    # CHANGE REDIRECT IF LOOP & CANDIDATES TO POPULATE
    if params['loop']
      loop_method = params['loop_if']
      loop_to = params['loop']
      candidates = Candidate.where(id: session['candidates']).select{ |c| !c.send(loop_method) }
      if candidates.size > 0
        next_step = loop_to
        session['current_candidate'] = candidates.first.id
      end
    end

    # REDIRECT TO STEP OR PATH
    redirect(next_step)
  end

  private

  def redirect(next_step)
    if next_step[-5,5] == "_path"
      session['current_candidate'] = session['candidates'].first
      redirect_to send next_step # as a PATH
    else
      redirect_to step_path(next_step) # as an ID
    end
  end

  def set_steps_list
    @steps = YAML.load_file(Rails.root + 'config/steps.yml')
    #@steps['step1.1']
  end

  def set_step
    step_id = params['id'] ? params['id'] : @steps['init']
    @step = @steps[step_id]
    # customize
  end

  def step_params
     params.require(:candidate).permit(:id, :dossier_zip, :dossier_people, :dossier_max_rent)
  end

  def set_candidate
    if session['current_candidate']
      @current_candidate = Candidate.find(session['current_candidate'])
    end
  end

  def customize_step
    if @current_candidate
      @step['questions'].each do |question|
        regex = /%:.+%/
        match = regex.match(question[1]['text'])
        if match
          value = @current_candidate.send(match.to_s[2,match.to_s.size - 3])
          question[1]['text'] = question[1]['text'].gsub(match.to_s, value.to_s)
        end

      end
    end
  end


end
