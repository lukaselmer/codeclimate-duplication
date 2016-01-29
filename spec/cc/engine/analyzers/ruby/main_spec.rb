require 'spec_helper'
require 'cc/engine/analyzers/ruby/main'
require 'cc/engine/analyzers/engine_config'
require 'cc/engine/analyzers/file_list'

module CC::Engine::Analyzers
  RSpec.describe Ruby::Main, in_tmpdir: true do
    include AnalyzerSpecHelpers

    describe "#run" do
      it "prints an issue" do
        create_source_file("foo.rb", <<-EORUBY)
            describe '#ruby?' do
              before { subject.type = 'ruby' }

              it 'returns true' do
                expect(subject.ruby?).to be true
              end
            end

            describe '#js?' do
              before { subject.type = 'js' }

              it 'returns true' do
                expect(subject.js?).to be true
              end
            end
        EORUBY

        issues = run_engine(engine_conf).strip.split("\0")
        result = issues.first.strip
        json = JSON.parse(result)

        expect(json["type"]).to eq("issue")
        expect(json["check_name"]).to eq("Similar code")
        expect(json["description"]).to eq("Similar code found in 1 other location (mass = 18)")
        expect(json["categories"]).to eq(["Duplication"])
        expect(json["location"]).to eq({
          "path" => "foo.rb",
          "lines" => { "begin" => 1, "end" => 5 },
        })
        expect(json["remediation_points"]).to eq(1_500_000)
        expect(json["other_locations"]).to eq([
          {"path" => "foo.rb", "lines" => { "begin" => 9, "end" => 13} },
        ])
        expect(json["content"]["body"]).to match /This issue has a mass of `18`/
        expect(json["fingerprint"]).to eq("b7e46d8f5164922678e48942e26100f2")
      end

      it "creates an issue for each occurrence of the duplicated code" do
        create_source_file("foo.rb", <<-EORUBY)
            describe '#ruby?' do
              before { subject.type = 'ruby' }

              it 'returns true' do
                expect(subject.ruby?).to be true
              end
            end

            describe '#js?' do
              before { subject.type = 'js' }

              it 'returns true' do
                expect(subject.js?).to be true
              end
            end

            describe '#whaddup?' do
              before { subject.type = 'js' }

              it 'returns true' do
                expect(subject.js?).to be true
              end
            end
        EORUBY

        issues = run_engine(engine_conf).strip.split("\0")

        expect(issues.length).to eq(3)
      end

      it "skips unparsable files" do
        create_source_file("foo.rb", <<-EORUBY)
          ---
        EORUBY

        expect {
          expect(run_engine(engine_conf)).to eq("")
        }.to output(/Skipping file/).to_stderr
      end

      it "analyzes erb files" do
        create_source_file("recipe.erb", <<-EOERB)
<div class="container">
  <h1>Select a Category</h1>
  <ul>
  <%categories.each do |category| %>
  <li> <a href= "/category/<%=category.id%>"><%=category.name%> | <%=category.recipes.count%> Recipes </a></li>
  <%end%>

  <%categories.each do |category| %>
    <li> <a href= "/category/<%=category.id%>"><%=category.name%> | <%=category.recipes.count%> Recipes </a></li>
  <%end%>

  <%categories.each do |category| %>
    <li> <a href= "/category/<%=category.id%>"><%=category.name%> | <%=category.recipes.count%> Recipes </a></li>
  <%end%>
</ul>
</div>
        EOERB

        issues = run_engine(engine_conf).strip.split("\0")
        result = issues.first.strip
        json = JSON.parse(result)

        expect(json["type"]).to eq("issue")
        expect(json["check_name"]).to eq("Similar code")
        expect(json["description"]).to eq("Similar code found in 2 other locations (mass = 30)")
        expect(json["categories"]).to eq(["Duplication"])
        expect(json["location"]).to eq({
          "path" => "recipe.erb",
          "lines" => { "begin" => 4, "end" => 5 },
        })
        expect(json["remediation_points"]).to eq(2_700_000)
        expect(json["other_locations"]).to eq([
          {"path" => "recipe.erb", "lines" => { "begin" => 8, "end" => 9} },
          {"path" => "recipe.erb", "lines" => { "begin" => 12, "end" => 13} }
         ])
      end
    end

    describe "#calculate_points(mass)" do
      let(:analyzer) { Ruby::Main.new(engine_config: engine_conf) }
      let(:base_points) { Ruby::Main::BASE_POINTS }
      let(:points_per) { Ruby::Main::POINTS_PER_OVERAGE }
      let(:threshold) { Ruby::Main::DEFAULT_MASS_THRESHOLD }

      context "when mass exceeds threshold" do
        it "calculates mass overage points" do
          mass = threshold + 10
          overage = mass - threshold

          expected_points = base_points + overage * points_per
          points = analyzer.calculate_points(mass)

          expect(points).to eq(expected_points)
        end
      end

      context "when mass is less than threshold" do
        it "calculates mass overage points" do
          mass = threshold - 5
          overage = mass - threshold

          expected_points = base_points + overage * points_per
          points = analyzer.calculate_points(mass)

          expect(points).to eq(expected_points)
        end
      end

      context "when mass equals threshold" do
        it "calculates mass overage points" do
          mass = threshold
          overage = mass - threshold

          expected_points = base_points + overage * points_per
          points = analyzer.calculate_points(mass)

          expect(points).to eq(expected_points)
        end
      end
    end

    def engine_conf
      EngineConfig.new({})
    end
  end
end
