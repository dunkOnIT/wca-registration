# frozen_string_literal: true

module ErrorCodes
  # System Errors
  INVALID_TOKEN = -1
  EXPIRED_TOKEN = -2
  MISSING_AUTHENTICATION = -3

  # Competition Errors
  COMPETITION_NOT_FOUND = -1000
  COMPETITION_API_5XX = -1001

  # User Errors
  USER_CANNOT_COMPETE = -2001
  USER_INSUFFICIENT_PERMISSIONS = -2003

  # Registration errors
  REGISTRATION_NOT_FOUND = -3000

  # Request errors
  INVALID_REQUEST_DATA = -4000
  USER_EDITS_NOT_ALLOWED = -4001
  GUEST_LIMIT_EXCEEDED = -4002
  USER_COMMENT_TOO_LONG = -4003
  INVALID_EVENT_SELECTION = -4004
  REQUIRED_COMMENT_MISSING = -4005
  COMPETITOR_LIMIT_REACHED = -4006
  INVALID_REGISTRATION_STATUS = -4007
  REGISTRATION_CLOSED = -4008
  ORGANIZER_MUST_CANCEL_REGISTRATION = -4009
  INVALID_WAITING_LIST_POSITION = -4010
  MUST_ACCEPT_WAITING_LIST_LEADER = -4011
  QUALIFICATION_NOT_MET = -4012

  # Payment Errors
  PAYMENT_NOT_ENABLED = -3001
  PAYMENT_NOT_READY = -3002
end
