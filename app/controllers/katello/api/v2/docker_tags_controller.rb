module Katello
  class Api::V2::DockerTagsController < Api::V2::ApiController
    apipie_concern_subst(:a_resource => N_("a docker tag"), :resource => "docker_tags")
    include Katello::Concerns::Api::V2::RepositoryContentController

    def index
      if params[:grouped]
        # group docker tags by name, repo, and product
        repos = Repository.readable
        repos = repos.in_organization(@organization) if @organization
        collection = Katello::DockerTag.in_repositories(repos).grouped

        respond(:collection => scoped_search(collection, "name", "DESC"))
      else
        super
      end
    end

    private

    def resource_class
      DockerTag
    end
  end
end
