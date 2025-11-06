class Storage
  DATA_DIR = Rails.root.join('data')

  class << self
    def save_numbers(numbers)
      write_json('phone_numbers.json', numbers)
    end

    def load_numbers
      read_json('phone_numbers.json') || []
    end

    def save_call_log(log)
      logs = load_call_logs
      logs << log
      write_json('call_logs.json', logs)
    end

    def save_call_logs(logs)
      write_json('call_logs.json', logs)
    end

    def load_call_logs
      read_json('call_logs.json') || []
    end

    def save_blog_articles(articles)
      write_json('blog_articles.json', articles)
    end

    def load_blog_articles
      read_json('blog_articles.json') || []
    end

    private

    def write_json(filename, data)
      FileUtils.mkdir_p(DATA_DIR) unless Dir.exist?(DATA_DIR)
      File.write(DATA_DIR.join(filename), JSON.pretty_generate(data))
    end

    def read_json(filename)
      file_path = DATA_DIR.join(filename)
      return nil unless File.exist?(file_path)
      JSON.parse(File.read(file_path))
    end
  end
end