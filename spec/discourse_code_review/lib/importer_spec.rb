# frozen_string_literal: true

require 'rails_helper'

module DiscourseCodeReview
  describe Importer do
    def first_post_of(topic_id)
      Topic.find(topic_id).posts.order(:id).first
    end

    it "can look up a category id consistently" do

      # lets muck stuff up first ... and create a dupe category
      Category.create!(name: 'discourse', user: Discourse.system_user)

      repo = GithubRepo.new("discourse/discourse", Octokit::Client.new, nil)
      id = Importer.new(repo).category_id

      expect(id).to be > 0
      expect(Importer.new(repo).category_id).to eq(id)
    end

    it "can cleanly associate old commits" do
      repo = GithubRepo.new("discourse/discourse", Octokit::Client.new, nil)

      diff = "```\nwith a diff"

      commit = {
        subject: "hello world",
        body: "this is the body",
        email: "sam@sam.com",
        github_login: "sam",
        github_id: "111",
        date: 1.day.ago,
        diff: diff,
        hash: "a1db15feadc7951d8a2b4ae63384babd6c568ae0"
      }

      repo.expects(:master_contains?).with(commit[:hash]).returns(true)

      post = first_post_of(Importer.new(repo).import_commit(commit))

      commit[:hash] = "dbbadb5c357bc23daf1fa732f8670e55dc28b7cb"
      commit[:body] = "ab2787347ff (this is\nfollowing up on a1db15fe)"

      repo.expects(:master_contains?).with(commit[:hash]).returns(true)

      post2 = first_post_of(Importer.new(repo).import_commit(commit))

      expect(post2.cooked).to include(post.topic.url)

      # expect a backlink
      expect(post.topic.posts.length).to eq(2)

    end

    it "can handle complex imports" do

      repo = GithubRepo.new("discourse/discourse", Octokit::Client.new, nil)

      diff = "```\nwith a diff"

      body = <<~MD
      this is [amazing](http://amaz.ing)
      MD

      commit = {
        subject: "hello world",
        body: body,
        email: "sam@sam.com",
        github_login: "sam",
        github_id: "111",
        date: 1.day.ago,
        diff: diff,
        hash: SecureRandom.hex
      }

      repo.expects(:master_contains?).with(commit[:hash]).returns(true)

      post = first_post_of(Importer.new(repo).import_commit(commit))

      expect(post.cooked.scan("code").length).to eq(2)
      expect(post.excerpt).to eq("this is <a href=\"http://amaz.ing\">amazing</a>")
    end
  end
end
