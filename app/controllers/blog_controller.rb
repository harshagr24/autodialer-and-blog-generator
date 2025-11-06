class BlogController < ApplicationController
  def index
    @articles = Storage.load_blog_articles
    render json: { articles: @articles }
  end

  def show
    articles = Storage.load_blog_articles
    article = articles.find { |a| a['slug'] == params[:id] }
    
    if article
      render json: { article: article }
    else
      render json: { error: 'Article not found' }, status: :not_found
    end
  end

  def generate
    titles_with_details = params[:titles]
    
    unless titles_with_details.present?
      render json: { error: 'No titles provided' }, status: :bad_request
      return
    end

    unless ENV['OPENAI_API_KEY'].present?
      render json: { error: 'OpenAI API key not configured' }, status: :unauthorized
      return
    end

    begin
      # Parse the input (can be array or newline-separated string)
      title_list = if titles_with_details.is_a?(Array)
        titles_with_details
      else
        titles_with_details.split("\n").map(&:strip).reject(&:empty?)
      end

      generated_articles = []
      client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

      title_list.each do |title_detail|
        Rails.logger.info "Generating article for: #{title_detail}"
        
        # Generate article content using ChatGPT
        response = client.chat(
          parameters: {
            model: "gpt-3.5-turbo",
            messages: [
              {
                role: "system",
                content: "You are a professional technical writer. Write comprehensive, well-structured blog articles about programming topics. Include an introduction, multiple sections with headings, code examples where relevant, and a conclusion. Format the article in HTML with proper tags like <h2>, <h3>, <p>, <pre><code>, <ul>, <ol>, etc. Make it engaging and informative."
              },
              {
                role: "user",
                content: "Write a detailed blog article about: #{title_detail}\n\nProvide the full article content in HTML format."
              }
            ],
            temperature: 0.7,
            max_tokens: 2000
          }
        )

        content = response.dig("choices", 0, "message", "content")
        
        # Extract title if not already clean
        clean_title = title_detail.split(/[-–:]/).first&.strip || title_detail
        
        # Create slug from title
        slug = clean_title.downcase
                         .gsub(/[^a-z0-9\s-]/, '')
                         .gsub(/\s+/, '-')
                         .gsub(/-+/, '-')
        
        article = {
          title: clean_title,
          slug: slug,
          content: content,
          created_at: Time.current.iso8601,
          updated_at: Time.current.iso8601
        }
        
        generated_articles << article
        Rails.logger.info "Generated article: #{clean_title}"
        
        # Small delay to avoid rate limiting
        sleep(1) unless title_detail == title_list.last
      end

      # Save all articles
      existing_articles = Storage.load_blog_articles
      all_articles = existing_articles + generated_articles
      Storage.save_blog_articles(all_articles)

      render json: {
        success: true,
        message: "Generated #{generated_articles.length} articles",
        articles: generated_articles.map { |a| { title: a[:title], slug: a[:slug] } }
      }

    rescue OpenAI::Error => e
      Rails.logger.error "OpenAI Error: #{e.message}"
      render json: { error: "Failed to generate articles: #{e.message}" }, status: :service_unavailable
    rescue StandardError => e
      Rails.logger.error "Error generating articles: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Failed to generate articles: #{e.message}" }, status: :internal_server_error
    end
  end

  def delete_all
    Storage.save_blog_articles([])
    render json: { success: true, message: 'All articles deleted' }
  end
end
