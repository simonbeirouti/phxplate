import { Socket } from "phoenix";

// Initialize the socket connection
let socket = null;

// Local storage keys
const STORAGE_KEYS = {
  ANONYMOUS_NAME: 'phxplate_anonymous_name',
  ANONYMOUS_EMAIL: 'phxplate_anonymous_email',
  CHAT_SESSIONS: 'phxplate_chat_sessions'
};

// Initialize the socket
function initSocket() {
  if (!socket) {
    socket = new Socket("/socket");
    socket.connect();
  }
  return socket;
}

// Chat hooks for the application
const ChatHooks = {
  // Hook for scrolling chat messages
  ScrollChat: {
    mounted() {
      this.scrollToBottom();

      // Set up a mutation observer to scroll to bottom when new messages are added
      const observer = new MutationObserver(() => {
        this.scrollToBottom();
      });

      observer.observe(this.el, { childList: true });
    },

    scrollToBottom() {
      this.el.scrollTop = this.el.scrollHeight;
    }
  },

  // Hook for the chat button that shows/hides the chat modal
  ChatButton: {
    mounted() {
      // Store references to the icons
      this.chatIcon = this.el.querySelector('.chat-icon');
      this.closeIcon = this.el.querySelector('.close-icon');
      this.isOpen = false;

      this.el.addEventListener("click", () => {
        const chatModal = document.getElementById("chat-modal");
        if (chatModal) {
          // Toggle modal visibility
          chatModal.classList.toggle("hidden");

          // Toggle icon visibility
          this.isOpen = !this.isOpen;
          this.toggleIcon();
        }
      });

      // Listen for events that might close the modal from elsewhere
      document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && this.isOpen) {
          const chatModal = document.getElementById("chat-modal");
          if (chatModal && !chatModal.classList.contains('hidden')) {
            chatModal.classList.add('hidden');
            this.isOpen = false;
            this.toggleIcon();
          }
        }
      });

      // Listen for close button clicks in the modal
      const closeButton = document.getElementById('close-chat-button');
      if (closeButton) {
        closeButton.addEventListener('click', () => {
          this.isOpen = false;
          this.toggleIcon();
        });
      }
    },

    toggleIcon() {
      if (this.isOpen) {
        this.chatIcon.classList.add('hidden');
        this.closeIcon.classList.remove('hidden');
      } else {
        this.chatIcon.classList.remove('hidden');
        this.closeIcon.classList.add('hidden');
      }
    }
  },

  // Hook for the chat modal
  ChatModal: {
    mounted() {
      this.socket = initSocket();
      this.channel = null;
      this.sessionId = null;
      this.showingSettings = false;
      
      // Check if we have stored anonymous user data
      this.anonymousName = localStorage.getItem(STORAGE_KEYS.ANONYMOUS_NAME);
      this.anonymousEmail = localStorage.getItem(STORAGE_KEYS.ANONYMOUS_EMAIL);
      this.previousSessions = JSON.parse(localStorage.getItem(STORAGE_KEYS.CHAT_SESSIONS) || '[]');
      
      // If we have an email, fetch sessions from the server
      if (this.anonymousEmail) {
        this.fetchAnonymousSessions(this.anonymousEmail);
      }

      // Close button event listener
      const closeButton = this.el.querySelector("#close-chat-button");
      if (closeButton) {
        closeButton.addEventListener("click", () => {
          this.el.classList.add("hidden");
          if (this.channel) {
            this.channel.leave();
            this.channel = null;
          }

          // Notify the chat button to update its icon
          const chatButton = document.getElementById("chat-toggle-button");
          if (chatButton && chatButton._phxHook) {
            // Access the hook instance and update the state
            const chatButtonHook = chatButton._phxHook;
            chatButtonHook.isOpen = false;
            chatButtonHook.toggleIcon();
          }
        });
      }

      // Start chat button event listener for logged-in users
      const startChatButton = this.el.querySelector("#start-chat-button");
      if (startChatButton) {
        startChatButton.addEventListener("click", () => {
          this.startChat({});
        });
      }
      
      // Initialize the chat interface based on user state
      this.initializeChatInterface();
    },

    initializeChatInterface() {
      // Clear the modal content first
      const modalContent = this.el.querySelector(".chat-modal-content");
      if (!modalContent) {
        return;
      }
      
      // If we have user info already, show previous chats or start new chat options
      if (this.anonymousName && this.anonymousEmail) {
        // Always fetch the latest sessions from the server
        this.fetchAnonymousSessions(this.anonymousEmail);
      } else {
        // Otherwise show the registration form
        this.renderRegistrationForm();
      }
    },
    
    renderUserDashboard() {
      // Update the header to include settings button
      const modalHeader = this.el.querySelector(".chat-modal-header");
      modalHeader.innerHTML = `
        <h3 class="text-lg font-semibold">Chat with Support</h3>
        <div class="flex items-center gap-2">
          <button id="chat-settings-button" class="text-white hover:text-gray-200 bg-gray-600 hover:bg-gray-700 px-2 py-1 text-sm rounded">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M11.49 3.17c-.38-1.56-2.6-1.56-2.98 0a1.532 1.532 0 01-2.286.948c-1.372-.836-2.942.734-2.106 2.106.54.886.061 2.042-.947 2.287-1.561.379-1.561 2.6 0 2.978a1.532 1.532 0 01.947 2.287c-.836 1.372.734 2.942 2.106 2.106a1.532 1.532 0 012.287.947c.379 1.561 2.6 1.561 2.978 0a1.533 1.533 0 012.287-.947c1.372.836 2.942-.734 2.106-2.106a1.533 1.533 0 01.947-2.287c1.561-.379 1.561-2.6 0-2.978a1.532 1.532 0 01-.947-2.287c.836-1.372-.734-2.942-2.106-2.106a1.532 1.532 0 01-2.287-.947zM10 13a3 3 0 100-6 3 3 0 000 6z" clip-rule="evenodd" />
            </svg>
          </button>
        </div>
      `;
      
      // Add event listener for settings button
      const settingsButton = modalHeader.querySelector('#chat-settings-button');
      if (settingsButton) {
        settingsButton.addEventListener('click', () => {
          this.showingSettings = true;
          this.renderSettingsForm();
        });
      }
      
      const modalBody = this.el.querySelector(".chat-modal-body");
      if (!modalBody) return;
      
      // Clear the modal body first
      modalBody.innerHTML = '';
      
      // Create container for the entire dashboard
      const dashboardContainer = document.createElement('div');
      dashboardContainer.className = 'chat-dashboard-container flex flex-col h-full';
      modalBody.appendChild(dashboardContainer);
      
      // Add previous sessions at the top
      if (this.previousSessions && this.previousSessions.length > 0) {
        const previousSessionsContainer = document.createElement('div');
        previousSessionsContainer.className = 'previous-sessions flex-grow overflow-y-auto';
        previousSessionsContainer.innerHTML = `
          <h4 class="text-md font-medium mb-2 px-2 pt-1">Your Previous Conversations</h4>
          <div class="previous-sessions-list"></div>
        `;
        
        const sessionsList = previousSessionsContainer.querySelector('.previous-sessions-list');
        
        // Sort sessions by date (newest first)
        const sortedSessions = [...this.previousSessions].sort((a, b) => {
          return new Date(b.date) - new Date(a.date);
        });
        
        // Add each session as a compact row
        sortedSessions.forEach(session => {
          const sessionCard = document.createElement('div');
          sessionCard.className = 'session-card bg-white border border-gray-200 rounded-lg p-3 hover:shadow-md transition-shadow cursor-pointer mx-2 mb-3 flex justify-between items-center';
          
          // Format date nicely - just time
          const sessionDate = new Date(session.date);
          const formattedDate = sessionDate.toLocaleDateString([], { day: '2-digit', month: '2-digit', year: 'numeric' });
          const formattedTime = sessionDate.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
          
          // Create status badge
          const statusBadge = `<span class="inline-block px-2 py-0.5 text-xs rounded-full ${session.status === 'closed' ? 'bg-gray-200 text-gray-800' : 'bg-green-100 text-green-800'}">
            ${session.status === 'closed' ? 'Closed' : 'Active'}
          </span>`;
          
          // Create content for the session card - only essential info
          sessionCard.innerHTML = `
            <div class="flex flex-col items-start gap-2">
              <div class="text-xs text-gray-500">${formattedDate}</div>
              <div class="text-xs text-gray-500">${formattedTime}</div>
            </div>
            <div class="flex items-center gap-2">
              ${statusBadge}
              <button class="continue-chat-button text-primary">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M7.293 14.707a1 1 0 010-1.414L10.586 10 7.293 6.707a1 1 0 011.414-1.414l4 4a1 1 0 010 1.414l-4 4a1 1 0 01-1.414 0z" clip-rule="evenodd" />
                </svg>
              </button>
            </div>
          `;
          
          // Add event listener for continue button
          const continueButton = sessionCard.querySelector('.continue-chat-button');
          if (continueButton) {
            continueButton.addEventListener('click', (e) => {
              e.stopPropagation(); // Prevent the card click from triggering
              this.joinExistingSession(session.id);
            });
          }
          
          // Make the whole card clickable
          sessionCard.addEventListener('click', () => {
            this.joinExistingSession(session.id);
          });
          
          sessionsList.appendChild(sessionCard);
        });
        
        dashboardContainer.appendChild(previousSessionsContainer);
      } else {
        // Show a message if no previous sessions
        const noSessionsMessage = document.createElement('div');
        noSessionsMessage.className = 'text-center text-gray-500 flex-grow flex items-center justify-center';
        noSessionsMessage.textContent = 'No previous conversations found.';
        dashboardContainer.appendChild(noSessionsMessage);
      }
      
      // Add new chat button at the bottom
      const newChatButtonContainer = document.createElement('div');
      newChatButtonContainer.className = 'mt-auto pt-2 px-2 pb-2';
      newChatButtonContainer.innerHTML = `
        <button id="new-chat-button" class="w-full bg-primary hover:bg-primary/80 text-white font-medium py-2 px-4 rounded flex justify-center items-center">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 mr-1" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 3a1 1 0 011 1v5h5a1 1 0 110 2h-5v5a1 1 0 11-2 0v-5H4a1 1 0 110-2h5V4a1 1 0 011-1z" clip-rule="evenodd" />
          </svg>
          Start New Chat
        </button>
      `;
      dashboardContainer.appendChild(newChatButtonContainer);
      
      // Add event listener for new chat button
      const newChatButton = newChatButtonContainer.querySelector('#new-chat-button');
      newChatButton.addEventListener('click', () => {
        this.startChat({
          name: this.anonymousName,
          email: this.anonymousEmail
        });
      });
    },
    
    renderSettingsForm() {
      const modalBody = this.el.querySelector(".chat-modal-body");
      if (!modalBody) return;
      
      // Clear the modal body
      modalBody.innerHTML = '';
      
      // Create settings form
      const settingsForm = document.createElement('form');
      settingsForm.id = 'chat-settings-form';
      settingsForm.className = 'space-y-4';
      settingsForm.innerHTML = `
        <div class="flex items-center mb-4">
          <button id="back-to-chats-button" class="mr-2">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M12.707 5.293a1 1 0 010 1.414L9.414 10l3.293 3.293a1 1 0 01-1.414 1.414l-4-4a1 1 0 010-1.414l4-4a1 1 0 011.414 0z" clip-rule="evenodd" />
            </svg>
          </button>
          <h3 class="text-lg font-medium">User Settings</h3>
        </div>
        
        <div>
          <label for="settings-name" class="block text-sm font-medium text-gray-700 mb-1">Your Name</label>
          <input type="text" id="settings-name" class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-primary focus:border-primary" value="${this.anonymousName || ''}" required>
        </div>
        
        <div>
          <label for="settings-email" class="block text-sm font-medium text-gray-700 mb-1">Your Email</label>
          <input type="email" id="settings-email" class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-primary focus:border-primary" value="${this.anonymousEmail || ''}" required>
        </div>
        
        <div class="pt-2">
          <button type="submit" class="w-full bg-primary hover:bg-primary/80 text-white font-medium py-2 px-4 rounded">Save Changes</button>
        </div>
      `;
      
      modalBody.appendChild(settingsForm);
      
      // Add event listener for back button
      const backButton = settingsForm.querySelector('#back-to-chats-button');
      if (backButton) {
        backButton.addEventListener('click', (e) => {
          e.preventDefault();
          this.showingSettings = false;
          this.renderUserDashboard();
        });
      }
      
      // Add event listener for form submission
      settingsForm.addEventListener('submit', (e) => {
        e.preventDefault();
        
        const name = settingsForm.querySelector('#settings-name').value.trim();
        const email = settingsForm.querySelector('#settings-email').value.trim();
        
        if (name && email) {
          // Update local storage and instance variables
          localStorage.setItem(STORAGE_KEYS.ANONYMOUS_NAME, name);
          localStorage.setItem(STORAGE_KEYS.ANONYMOUS_EMAIL, email);
          this.anonymousName = name;
          this.anonymousEmail = email;
          
          // If email changed, fetch sessions for the new email
          this.fetchAnonymousSessions(email);
          
          // Go back to dashboard
          this.showingSettings = false;
          this.renderUserDashboard();
        }
      });
    },
    
    renderRegistrationForm() {
      const modalBody = this.el.querySelector(".chat-modal-body");
      if (!modalBody) return;
      
      // Create registration form
      const registrationForm = document.createElement('form');
      registrationForm.id = 'chat-form';
      registrationForm.className = 'space-y-4';
      registrationForm.innerHTML = `
        <h3 class="text-lg font-medium mb-4">Start a Conversation</h3>
        
        <div>
          <label for="name" class="block text-sm font-medium text-gray-700 mb-1">Your Name</label>
          <input type="text" id="name" class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-primary focus:border-primary" value="${this.anonymousName || ''}" required>
        </div>
        
        <div>
          <label for="email" class="block text-sm font-medium text-gray-700 mb-1">Your Email</label>
          <input type="email" id="email" class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-primary focus:border-primary" value="${this.anonymousEmail || ''}" required>
        </div>
        
        <div class="pt-2">
          <button type="submit" class="w-full bg-primary hover:bg-primary/80 text-white font-medium py-2 px-4 rounded">Start Chat</button>
        </div>
      `;
      
      modalBody.appendChild(registrationForm);
      
      // Add event listener for form submission
      registrationForm.addEventListener('submit', (e) => {
        e.preventDefault();
        
        const name = registrationForm.querySelector('#name').value.trim();
        const email = registrationForm.querySelector('#email').value.trim();
        
        if (name && email) {
          // Store in local storage
          localStorage.setItem(STORAGE_KEYS.ANONYMOUS_NAME, name);
          localStorage.setItem(STORAGE_KEYS.ANONYMOUS_EMAIL, email);
          this.anonymousName = name;
          this.anonymousEmail = email;
          
          // Fetch any existing sessions for this email
          this.fetchAnonymousSessions(email);
          
          // Start a new chat
          this.startChat({ name, email });
        }
      });
    },
    
    renderPreviousSessions() {
      // This is a placeholder for re-rendering just the previous sessions section
      // In practice, we're just calling renderUserDashboard to refresh the whole view
      if (this.anonymousName && this.anonymousEmail && !this.showingSettings && !this.channel) {
        this.renderUserDashboard();
      }
    },
    
    fetchAnonymousSessions(email) {
      fetch(`/api/chat/anonymous/${encodeURIComponent(email)}`)
        .then(response => {
          if (response.ok) {
            return response.json();
          }
          throw new Error('Failed to fetch sessions');
        })
        .then(data => {
          if (data.sessions && data.sessions.length > 0) {
            // Sort sessions by date (newest first) and take only the last 4
            const sortedSessions = data.sessions.sort((a, b) => {
              return new Date(b.started_at) - new Date(a.started_at);
            }).slice(0, 4);
            
            // Create minimal session objects with only the data we need
            // This reduces the amount of potentially sensitive data stored in localStorage
            const minimalSessions = sortedSessions.map(s => ({
              id: s.id,
              date: s.started_at,
              status: s.status,
              // Only store a preview of the last message, not the full content
              last_message: s.last_message ? {
                content: s.last_message.content ? s.last_message.content.substring(0, 30) : '',
                sender_type: s.last_message.sender_type
              } : null,
              message_count: s.message_count || 0
            }));
            
            // Update local storage with minimal data
            localStorage.setItem(STORAGE_KEYS.CHAT_SESSIONS, JSON.stringify(minimalSessions));
            this.previousSessions = minimalSessions;
            
            // If we have user info already, show the dashboard with previous sessions
            if (this.anonymousName && this.anonymousEmail) {
              this.renderUserDashboard();
            }
          } else {
            // Even if no sessions were found, we should still render the dashboard
            if (this.anonymousName && this.anonymousEmail) {
              this.renderUserDashboard();
            }
          }
        })
        .catch(error => {
          console.error('Error fetching anonymous sessions:', error);
          // Even if there's an error, we should still render the dashboard
          if (this.anonymousName && this.anonymousEmail) {
            this.renderUserDashboard();
          }
        });
    },
    
    joinExistingSession(sessionId) {
      // Convert sessionId to string if it's a number to ensure consistent comparison
      const sessionIdStr = String(sessionId);
      
      // Find the session in our previous sessions
      const session = this.previousSessions.find(s => String(s.id) === sessionIdStr);
      
      if (!session) {
        console.error('Session not found:', sessionId);
        return;
      }
      
      // Handle differently based on session status
      if (session.status === 'closed') {
        // For closed sessions, just view the chat history
        this.viewChatHistory(sessionIdStr);
      } else {
        // For open or pending sessions, join the existing session
        this.sessionId = sessionIdStr;
        // Skip the API call for creating a new session - just join the channel directly
        this.joinChatChannel();
        this.renderChatInterface();
      }
    },
    
    viewChatHistory(sessionId) {
      // Set the current session ID
      this.sessionId = sessionId;
      
      // Fetch the session with messages
      fetch(`/api/chat/${sessionId}?email=${encodeURIComponent(this.anonymousEmail)}`)
        .then(response => {
          if (response.ok) {
            return response.json();
          }
          throw new Error('Failed to fetch chat history');
        })
        .then(data => {
          if (data.session) {
            // Render a read-only chat interface
            this.renderChatHistoryInterface(data.session);
          } else {
            console.error('No session data returned');
          }
        })
        .catch(error => {
          console.error('Error fetching chat history:', error);
        });
    },
    
    renderChatHistoryInterface(session) {
      // Update the header to include a back button instead of end chat
      const modalHeader = this.el.querySelector(".chat-modal-header");
      modalHeader.innerHTML = `
        <div class="flex items-center">
          <button id="back-to-dashboard" class="mr-2 text-white hover:text-gray-200">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" viewBox="0 0 20 20" fill="currentColor">
              <path fill-rule="evenodd" d="M9.707 16.707a1 1 0 01-1.414 0l-6-6a1 1 0 010-1.414l6-6a1 1 0 011.414 1.414L5.414 9H17a1 1 0 110 2H5.414l4.293 4.293a1 1 0 010 1.414z" clip-rule="evenodd" />
            </svg>
          </button>
          <h3 class="text-lg font-semibold">Chat History (Closed)</h3>
        </div>
        <button id="close-chat-button" class="text-white hover:text-gray-200">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      `;
      
      // Add event listener for back button
      const backButton = modalHeader.querySelector('#back-to-dashboard');
      if (backButton) {
        backButton.addEventListener('click', () => {
          this.renderUserDashboard();
        });
      }
      
      // Clear the content area
      const modalBody = this.el.querySelector(".chat-modal-body");
      modalBody.innerHTML = `
        <div class="chat-interface-container flex flex-col h-[400px]">
          <div class="flex-grow overflow-y-auto">
            <div class="chat-messages flex flex-col gap-0.75rem pr-0.5" id="chat-messages"></div>
          </div>
          <div class="bg-gray-100 p-3 text-center text-sm text-gray-600 rounded-b-lg">
            This chat session is closed. You cannot send new messages.
          </div>
        </div>
      `;
      
      // Render the messages
      if (session.messages && session.messages.length > 0) {
        this.renderMessages(session.messages);
      } else {
        const messagesContainer = modalBody.querySelector('#chat-messages');
        messagesContainer.innerHTML = '<div class="text-center text-gray-500 my-4">No messages in this chat session.</div>';
      }
    },
    
    startChat(userData) {
      // If we're joining an existing session, use the session_id directly
      if (userData.session_id) {
        this.sessionId = userData.session_id;
        this.joinChatChannel();
        this.renderChatInterface();
        return;
      }
      
      // Otherwise create a new chat session via API
      fetch("/api/chat", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").getAttribute("content")
        },
        body: JSON.stringify({ chat: userData })
      })
        .then(response => response.json())
        .then(data => {
          if (data.session_id) {
            this.sessionId = data.session_id;
            
            // Store this new session in local storage
            const sessions = JSON.parse(localStorage.getItem(STORAGE_KEYS.CHAT_SESSIONS) || '[]');
            // Check if session already exists
            if (!sessions.some(s => s.id === data.session_id)) {
              sessions.push({
                id: data.session_id,
                date: new Date().toISOString(),
                status: 'open',
                name: userData.name,
                email: userData.email
              });
              localStorage.setItem(STORAGE_KEYS.CHAT_SESSIONS, JSON.stringify(sessions));
              this.previousSessions = sessions;
            }
            
            this.joinChatChannel();
            this.renderChatInterface();
          } else {
            console.error("Failed to create chat session");
          }
        })
        .catch(error => {
          console.error("Error creating chat session:", error);
        });
    },

    joinChatChannel() {
      if (!this.sessionId) return;

      const channel = this.socket.channel(`chat:session:${this.sessionId}`);

      channel.join()
        .receive("ok", (resp) => {
          console.log("Joined chat session successfully", resp);
          if (resp.messages) {
            this.renderMessages(resp.messages);
          }
        })
        .receive("error", (resp) => {
          console.error("Unable to join chat session", resp);
        });

      // Handle new messages from the server
      channel.on("new_message", (payload) => {
        this.addMessage(payload.message);
      });

      // Handle session closed event
      channel.on("session_closed", () => {
        this.renderSessionClosed();
      });

      this.channel = channel;
    },

    renderChatInterface() {
      // Update the header to include only End Chat button (no X button)
      const modalHeader = this.el.querySelector(".chat-modal-header");
      modalHeader.innerHTML = `
        <h3 class="text-lg font-semibold">Chat with Support</h3>
        <div class="flex items-center gap-2">
          <button id="end-chat-button" class="text-white hover:text-gray-200 bg-red-600 hover:bg-red-700 px-2 py-1 text-sm rounded">
            End Chat
          </button>
        </div>
      `;
      
      // Clear the content area
      const modalBody = this.el.querySelector(".chat-modal-body");
      modalBody.innerHTML = `
        <div class="chat-interface-container flex flex-col h-[400px]">
          <div class="flex-grow overflow-y-auto">
            <div class="chat-messages flex flex-col gap-0.75rem pr-0.5" id="chat-messages"></div>
          </div>
          <div class="mt-auto pt-4">
            <form id="message-form" class="chat-message-form">
              <div class="flex gap-2">
                <input type="text" name="message" placeholder="Type your message..." class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring-primary" />
                <button type="submit" class="bg-primary hover:bg-primary/80 text-white font-medium py-2 px-4 rounded">Send</button>
              </div>
            </form>
          </div>
        </div>
      `;

      // Add event listener for the End Chat button
      const endChatButton = this.el.querySelector("#end-chat-button");
      if (endChatButton) {
        endChatButton.addEventListener("click", () => {
          if (this.channel) {
            // Show confirmation overlay
            this.showEndChatConfirmation();
          }
        });
      }
      
      // Re-add the close button event listener since we replaced the header
      const closeButton = this.el.querySelector("#close-chat-button");
      if (closeButton) {
        closeButton.addEventListener("click", () => {
          this.el.classList.add("hidden");
          if (this.channel) {
            this.channel.leave();
            this.channel = null;
          }

          // Notify the chat button to update its icon
          const chatButton = document.getElementById("chat-toggle-button");
          if (chatButton && chatButton._phxHook) {
            // Access the hook instance and update the state
            const chatButtonHook = chatButton._phxHook;
            chatButtonHook.isOpen = false;
            chatButtonHook.toggleIcon();
          }
        });
      }

      // Add event listener for the message form
      const messageForm = modalBody.querySelector("#message-form");
      messageForm.addEventListener("submit", (e) => {
        e.preventDefault();
        const messageInput = messageForm.querySelector("input[name='message']");
        const content = messageInput.value.trim();

        if (content && this.channel) {
          this.channel.push("new_message", { content })
            .receive("ok", (resp) => {
              messageInput.value = "";
              // Don't add the message here as it will be broadcast back from the server
              // and handled by the channel.on("new_message") event
            })
            .receive("error", (resp) => {
              console.error("Error sending message", resp);
            });
        }
      });
    },

    renderMessages(messages) {
      const chatMessages = this.el.querySelector("#chat-messages");
      if (!chatMessages) return;

      messages.forEach(message => {
        this.addMessage(message);
      });

      // Scroll to bottom
      this.scrollToBottom();
    },

    scrollToBottom() {
      // Find the message container and its parent scrollable div
      const chatMessages = this.el.querySelector("#chat-messages");
      const scrollContainer = this.el.querySelector(".flex-grow.overflow-y-auto");

      if (scrollContainer) {
        scrollContainer.scrollTop = scrollContainer.scrollHeight;
      }
    },

    addMessage(message) {
      const chatMessages = this.el.querySelector("#chat-messages");
      if (!chatMessages) return;

      const messageElement = document.createElement("div");
      messageElement.className = `chat-message ${message.sender_type}`;
      messageElement.style.maxWidth = "80%";
      messageElement.style.padding = "0.75rem";
      messageElement.style.borderRadius = "0.5rem";
      messageElement.style.position = "relative";
      messageElement.style.alignSelf = message.sender_type === "user" ? "flex-end" : "flex-start";
      messageElement.style.backgroundColor = message.sender_type === "user" ? "#000000" : "#e5e7eb";
      messageElement.style.color = message.sender_type === "user" ? "white" : "#1f2937";

      // Handle different date formats from server and history view
      let timestamp;
      try {
        timestamp = new Date(message.inserted_at).toLocaleTimeString();
      } catch (e) {
        // Fallback to current time if date parsing fails
        timestamp = new Date().toLocaleTimeString();
      }

      messageElement.innerHTML = `
        <div class="message-content" style="word-break: break-word;">${message.content}</div>
        <div class="message-time" style="font-size: 0.75rem; opacity: 0.7; margin-top: 0.25rem;">${timestamp}</div>
      `;

      chatMessages.appendChild(messageElement);

      // Scroll the message container to the bottom
      this.scrollToBottom();
    },

    showEndChatConfirmation() {
      // Create overlay element
      const overlay = document.createElement('div');
      overlay.className = 'chat-confirmation-overlay absolute inset-0 bg-black bg-opacity-70 z-10 flex items-center justify-center';
      overlay.style.borderRadius = 'inherit';
      
      // Create confirmation dialog
      overlay.innerHTML = `
        <div class="bg-white p-6 rounded-lg shadow-lg max-w-xs w-full">
          <h3 class="text-lg font-medium text-gray-900 mb-4">End Chat Session?</h3>
          <p class="text-gray-600 mb-6">Are you sure you want to end this chat session? A transcript will be sent to your email.</p>
          <div class="flex justify-between gap-4">
            <button id="cancel-end-chat" class="flex-1 py-2 px-4 bg-gray-200 hover:bg-gray-300 text-gray-800 rounded transition-colors">
              Cancel
            </button>
            <button id="confirm-end-chat" class="flex-1 py-2 px-4 bg-red-600 hover:bg-red-700 text-white rounded transition-colors">
              End Chat
            </button>
          </div>
        </div>
      `;
      
      // Add overlay to the modal
      const chatModal = this.el;
      chatModal.appendChild(overlay);
      
      // Add event listeners
      const cancelButton = overlay.querySelector('#cancel-end-chat');
      const confirmButton = overlay.querySelector('#confirm-end-chat');
      
      cancelButton.addEventListener('click', () => {
        chatModal.removeChild(overlay);
      });
      
      confirmButton.addEventListener('click', () => {
        // Remove the overlay
        chatModal.removeChild(overlay);
        
        // Close the session
        this.channel.push("close_session", {})
          .receive("ok", () => {
            console.log("Chat session closed successfully");
            // The session_closed event will be handled by the channel.on("session_closed") handler
          })
          .receive("error", (resp) => {
            console.error("Error closing chat session", resp);
          });
      });
    },

    renderSessionClosed() {
      // Mark the session as closed in local storage
      if (this.sessionId) {
        const sessions = JSON.parse(localStorage.getItem(STORAGE_KEYS.CHAT_SESSIONS) || '[]');
        const updatedSessions = sessions.map(session => {
          if (session.id === this.sessionId) {
            return { ...session, status: 'closed' };
          }
          return session;
        });
        localStorage.setItem(STORAGE_KEYS.CHAT_SESSIONS, JSON.stringify(updatedSessions));
        this.previousSessions = updatedSessions;
      }
      
      // Update the header to remove the End Chat button
      const modalHeader = this.el.querySelector(".chat-modal-header");
      modalHeader.innerHTML = `
        <h3 class="text-lg font-semibold">Chat with Support</h3>
        <button id="close-chat-button" class="text-white hover:text-gray-200">
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      `;
      
      // Re-add the close button event listener
      const closeButton = this.el.querySelector("#close-chat-button");
      if (closeButton) {
        closeButton.addEventListener("click", () => {
          this.el.classList.add("hidden");
          if (this.channel) {
            this.channel.leave();
            this.channel = null;
          }

          // Notify the chat button to update its icon
          const chatButton = document.getElementById("chat-toggle-button");
          if (chatButton && chatButton._phxHook) {
            const chatButtonHook = chatButton._phxHook;
            chatButtonHook.isOpen = false;
            chatButtonHook.toggleIcon();
          }
        });
      }
      
      // Update the body content
      const modalBody = this.el.querySelector(".chat-modal-body");
      modalBody.innerHTML = `
        <div class="chat-interface-container flex flex-col h-[400px]">
          <div class="mb-6">
            <p class="text-center font-medium">Chat Session Ended</p>
          </div>
          
          <div class="flex-grow flex items-center justify-center">
            <div class="text-center">
              <p class="mb-2">This chat session has ended. A transcript has been sent to your email.</p>
              <p class="mb-4">Thank you for contacting our support team!</p>
            </div>
          </div>
          
          <div class="mt-auto pt-6">
            <button id="new-chat-button" class="w-full bg-primary hover:bg-primary/80 text-white font-medium py-2 px-4 rounded">Start New Chat</button>
          </div>
        </div>
      `;

      // Set up the countdown and auto-redirect to dashboard
      let seconds = 4;
      const countdownElement = modalBody.querySelector("#countdown");
      const countdownInterval = setInterval(() => {
        seconds--;
        // if (countdownElement) {
        //   countdownElement.textContent = seconds;
        // }
        if (seconds <= 0) {
          clearInterval(countdownInterval);
          // Reset the channel
          if (this.channel) {
            this.channel.leave();
            this.channel = null;
          }
          this.sessionId = null;
          // Fetch the latest sessions and render the dashboard
          this.fetchAnonymousSessions(this.anonymousEmail);
        }
      }, 1000);
      
      // Still allow manual navigation via button
      const newChatButton = modalBody.querySelector("#new-chat-button");
      newChatButton.addEventListener("click", () => {
        clearInterval(countdownInterval); // Clear the interval to prevent multiple redirects
        // Reset the channel
        if (this.channel) {
          this.channel.leave();
          this.channel = null;
        }
        this.sessionId = null;
        // Start a new chat directly
        this.startChat({
          name: this.anonymousName,
          email: this.anonymousEmail
        });
      });
    }
  },

  // Hook for the admin chat dashboard
  AdminChatDashboard: {
    mounted() {
      this.socket = initSocket();
      this.joinAdminChannel();
    },

    joinAdminChannel() {
      const channel = this.socket.channel("admin:chat");

      channel.join()
        .receive("ok", (resp) => {
          console.log("Joined admin chat channel successfully", resp);
          if (resp.sessions) {
            this.renderSessions(resp.sessions);
          }
        })
        .receive("error", (resp) => {
          console.error("Unable to join admin chat channel", resp);
        });

      // Handle new sessions
      channel.on("new_session", (payload) => {
        this.addSession(payload.session);
      });

      // Handle new messages
      channel.on("new_message", (payload) => {
        this.addMessage(payload.message);
      });

      // Handle session closed
      channel.on("session_closed", (payload) => {
        this.updateSessionStatus(payload.session);
      });

      this.channel = channel;
    }
  }
};

export default ChatHooks;
