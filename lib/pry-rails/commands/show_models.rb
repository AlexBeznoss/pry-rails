# frozen_string_literal: true

class PryRails::ShowModels < Pry::ClassCommand
  match 'show-models'
  group 'Rails'
  description 'Show all models.'

  def options(opt)
    opt.banner unindent <<-USAGE
      Usage: show-models

      show-models displays the current Rails app's models.
    USAGE

    opt.on :G, 'grep', 'Filter output by regular expression', argument: true
  end

  def process
    Rails.application.eager_load!

    @formatter = PryRails::ModelFormatter.new

    display_activerecord_models
    display_mongoid_models
  end

  def display_activerecord_models
    return unless defined?(ActiveRecord::Base)

    models = ActiveRecord::Base.descendants

    models.sort_by(&:to_s).each do |model|
      print_unless_filtered @formatter.format_active_record(model)
    end
  end

  def display_mongoid_models
    return unless defined?(Mongoid::Document)

    models = []

    mongo = ->(obj) do
      return false unless obj.instance_of?(Class)
      return false unless obj.ancestors.include?(Mongoid::Document)
      return false if obj.ancestors.include? Mongoid::GlobalDiscriminatorKeyAssignment::InvalidFieldHost

      true
    end

    ObjectSpace.each_object do |o|
      next if ActiveSupport::Deprecation::DeprecationProxy === o

      is_model = false

      begin
        is_model = mongo[o]
      rescue StandardError => e
        p e
      end

      models << o if is_model
    end

    models.sort_by(&:to_s).each do |model|
      print_unless_filtered @formatter.format_mongoid(model)
    end
  end

  def print_unless_filtered(str)
    if opts.present?(:G)
      return unless str =~ grep_regex

      str = colorize_matches(str) # :(
    end
    output.puts str
  end

  def colorize_matches(string)
    if Pry.color
      string.to_s.gsub(grep_regex) { |s| "\e[7m#{s}\e[27m" }
    else
      string
    end
  end

  def grep_regex
    @grep_regex ||= Regexp.new(opts[:G], Regexp::IGNORECASE)
  end
end

PryRails::Commands.add_command PryRails::ShowModels
