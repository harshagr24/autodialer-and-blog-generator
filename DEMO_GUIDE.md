# Autodialer Project Demonstration Guide

## Project Overview
A complete Ruby on Rails autodialer application with AI-powered features including voice commands, bulk calling, AI chat assistant, and blog generation.

## Tech Stack
- **Backend**: Ruby on Rails 8.1.1 (API mode)
- **Frontend**: Pure HTML/CSS/JavaScript
- **APIs**: Twilio (calling), OpenAI Whisper (speech-to-text), OpenAI GPT-3.5 (chat & blog)
- **Storage**: JSON file-based storage system
- **Audio**: Browser MediaRecorder API

## Project Structure
```
autodialer/
├── app/
│   ├── controllers/
│   │   ├── blog_controller.rb           # AI blog generation
│   │   ├── call_queue_controller.rb     # Sequential calling system
│   │   ├── chat_controller.rb           # AI assistant
│   │   ├── phone_numbers_controller.rb  # Number management
│   │   ├── twilio_webhooks_controller.rb # Call status updates
│   │   └── voice_commands_controller.rb # Voice processing
│   ├── services/
│   │   ├── storage.rb                   # JSON file storage
│   │   └── twilio_service.rb           # Twilio API integration
│   └── models/
│       └── voice_settings.rb           # TTS configuration
├── config/
│   └── routes.rb                       # API routes
├── public/
│   ├── dashboard.html                  # Main interface
│   ├── blog.html                       # AI blog generator
│   └── voice.html                      # Standalone voice commands
└── data/                               # JSON storage
    ├── phone_numbers.json
    ├── call_logs.json
    └── blog_articles.json
```

## Demo Flow

### 1. Start the Application
```bash
# Set OpenAI API key
$env:OPENAI_API_KEY = "your-openai-api-key"

# Start server
rails server
```
Open: http://localhost:3000 (auto-redirects to dashboard)

### 2. Core Features Demo

#### A. Phone Number Management
**Location**: Dashboard → Phone Numbers section
**Code**: `app/controllers/phone_numbers_controller.rb`

```ruby
# Key method for bulk upload
def create
  numbers_text = params[:numbers]
  numbers = numbers_text.split("\n")
                       .map(&:strip)
                       .reject(&:empty?)
                       .map { |num| num.start_with?('+') ? num : "+91#{num}" }
  
  Storage.save_numbers(numbers)
  render json: { message: "Saved #{numbers.length} numbers", count: numbers.length }
end
```

**Demo Steps**:
1. Paste phone numbers in textarea
2. Click "Save Numbers" 
3. Show real-time count update

#### B. Sequential Calling System
**Location**: Dashboard → Calling Controls
**Code**: `app/controllers/call_queue_controller.rb`

```ruby
# Sequential calling with proper waiting
def start
  Thread.new do
    numbers.each_with_index do |number, index|
      break if @@stop_calling
      
      call = TwilioService.make_call(number)
      wait_for_call_completion(call.sid, number) # Wait for each call to finish
    end
  end
end
```

**Demo Steps**:
1. Click "Start Calling All Numbers"
2. Show live progress bar
3. Demonstrate "Stop Calling" functionality
4. Explain one-by-one calling vs simultaneous

#### C. Voice Commands with AI
**Location**: Dashboard → AI Assistant → Voice button
**Code**: `app/controllers/voice_commands_controller.rb`

```ruby
# OpenAI Whisper integration
def handle_voice_upload
  client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])
  
  response = client.audio.transcribe(
    parameters: {
      model: "whisper-1",
      file: audio_file
    }
  )
  
  command = response.dig("text")
  render json: { transcription: command, success: true }
end
```

**Demo Steps**:
1. Click "Voice" button
2. Say "Make a call to plus nine one eight five two nine..."
3. Show transcription appearing in chat input
4. Auto-execution of command

#### D. AI Chat Assistant
**Location**: Dashboard → AI Assistant
**Code**: `app/controllers/chat_controller.rb`

```ruby
# GPT-3.5 powered intent detection
def process_command
  response = client.chat(
    parameters: {
      model: "gpt-3.5-turbo",
      messages: [
        {
          role: "system", 
          content: "You are an AI assistant for an autodialer system..."
        },
        { role: "user", content: user_input }
      ]
    }
  )
end
```

**Demo Commands**:
- "Start calling all numbers"
- "Show me the call statistics"
- "Make a call to +918529166564"

#### E. AI Blog Generation
**Location**: Blog page → Generate Articles
**Code**: `app/controllers/blog_controller.rb`

```ruby
# ChatGPT article generation
def generate
  title_list.each do |title_detail|
    response = client.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: [
          {
            role: "system",
            content: "You are a professional technical writer..."
          },
          { role: "user", content: "Write a detailed blog article about: #{title_detail}" }
        ]
      }
    )
  end
end
```

**Demo Steps**:
1. Navigate to blog page
2. Enter article titles (one per line)
3. Click "Generate Articles with AI"
4. Show generated articles with proper HTML formatting

### 3. Technical Implementation Highlights

#### A. File-Based Storage System
**Code**: `app/services/storage.rb`

```ruby
class Storage
  def self.save_numbers(numbers)
    write_json('phone_numbers.json', numbers)
  end
  
  private
  
  def self.write_json(filename, data)
    FileUtils.mkdir_p(DATA_DIR)
    File.write(DATA_DIR.join(filename), JSON.pretty_generate(data))
  end
end
```

#### B. Twilio Integration with Status Tracking
**Code**: `app/services/twilio_service.rb`

```ruby
def self.make_call(to_number)
  call = client.calls.create(
    twiml: twiml.to_s,
    to: to_number,
    from: ENV['TWILIO_PHONE_NUMBER'],
    status_callback: "#{ENV['APP_URL']}/twilio/status",
    status_callback_event: ['completed', 'answered', 'busy', 'no-answer', 'failed']
  )
end
```

#### C. Real-Time Frontend Updates
**Code**: `public/dashboard.html`

```javascript
// Auto-refresh statistics every 5 seconds
setInterval(refreshStats, 5000);

async function refreshStats() {
  const response = await fetch('/call_queue/status');
  const data = await response.json();
  
  // Update progress bar
  if (data.queue_status.is_running) {
    const progress = (currentCall / totalNumbers) * 100;
    document.getElementById('progressBar').style.width = progress + '%';
  }
}
```

## Key Demo Points to Emphasize

### 1. **AI Integration**
- Voice-to-text using OpenAI Whisper
- Natural language processing with GPT-3.5
- Automated content generation

### 2. **Real-Time Features**
- Live call progress tracking
- Auto-updating statistics
- Responsive UI without page reloads

### 3. **Professional Call Management**
- Sequential calling (not spam-like simultaneous calls)
- Proper call status tracking via Twilio webhooks
- Graceful error handling and logging

### 4. **Clean Architecture**
- API-first design (Rails API mode)
- Separation of concerns (controllers, services, storage)
- RESTful endpoints

### 5. **User Experience**
- Intuitive dashboard interface
- Voice command capability
- Bulk operations support

## Environment Setup for Demo
```bash
# Required environment variables
TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token  
TWILIO_PHONE_NUMBER=+1234567890
OPENAI_API_KEY=sk-proj-...
APP_URL=http://localhost:3000
```

## API Endpoints Summary
```
GET  /                        → Redirect to dashboard
GET  /phone_numbers          → List numbers
POST /phone_numbers          → Save numbers
POST /call_queue/start       → Start sequential calling
GET  /call_queue/status      → Get call statistics
POST /call_queue/stop        → Stop calling
POST /voice_commands/process_voice → Process voice upload
POST /chat                   → AI chat assistant
GET  /api/blog              → List articles
POST /api/blog/generate     → Generate articles with AI
```

## Demo Script Suggestions

1. **Opening**: "This is a complete autodialer system built with Rails and AI"
2. **Show dashboard**: "Clean, modern interface with real-time statistics"
3. **Upload numbers**: "Bulk phone number management with validation"
4. **Voice demo**: "AI-powered voice commands using OpenAI Whisper"
5. **Start calling**: "Sequential calling system - professional, not spam"
6. **Show progress**: "Real-time progress tracking and status updates"
7. **AI chat**: "Natural language interface for system control"
8. **Blog feature**: "Bonus: AI content generation using ChatGPT"
9. **Code walkthrough**: "Clean architecture, API design, AI integration"

This demonstrates full-stack development, AI integration, real-time features, and professional telephony handling.