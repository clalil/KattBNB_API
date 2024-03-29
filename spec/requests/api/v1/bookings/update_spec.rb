RSpec.describe Api::V1::BookingsController, type: :request do
  let(:host1) { FactoryBot.create(:user, email: 'george@mail.com', nickname: 'Alonso') }
  let(:host2) { FactoryBot.create(:user, email: 'noel@craft.com', nickname: 'MacOS') }
  let(:user1) { FactoryBot.create(:user, email: 'faraz@craft.com', nickname: 'EarlyInTheMorning') }
  let(:booking) { FactoryBot.create(:booking, host_nickname: host1.nickname, user_id: user1.id, dates: [1562889600000, 1562976000000]) }
  let!(:profile1) { FactoryBot.create(:host_profile, user_id: host1.id, availability: [1562803200000, 1563062400000, 1563148800000], full_address: 'Arlanda Airport', description: 'It is a really fucking nice airport', latitude: 52.365598, longitude: 3.321478221)}
  let(:credentials_host1) { host1.create_new_auth_token }
  let(:credentials_host2) { host2.create_new_auth_token }
  let(:credentials_user1) { user1.create_new_auth_token }
  let(:headers_host1) { { HTTP_ACCEPT: 'application/json' }.merge!(credentials_host1) }
  let(:headers_host2) { { HTTP_ACCEPT: 'application/json' }.merge!(credentials_host2) }
  let(:headers_user1) { { HTTP_ACCEPT: 'application/json' }.merge!(credentials_user1) }
  let(:headers_no_auth) { { HTTP_ACCEPT: 'application/json' } }

  describe 'PATCH /api/v1/bookings/id' do

    it 'updates status of certain booking if action comes from associated host' do
      patch "/api/v1/bookings/#{booking.id}", params: {
        status: 'accepted',
        host_message: 'accepted by host'
      },
      headers: headers_host1
      expect(response.status).to eq 200
      expect(json_response['message']).to eq 'You have successfully updated this booking'
      booking.reload
      expect(booking.status).to eq 'accepted'
      expect(booking.host_message).to eq 'accepted by host'
      expect(profile1.availability).to eq [1562803200000, 1563062400000, 1563148800000]
      expect(booking.host_full_address).to eq profile1.full_address
      expect(booking.host_description).to eq profile1.description
      expect(booking.host_real_lat).to eq profile1.latitude
      expect(booking.host_real_long).to eq profile1.longitude
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end

    it 'adds back availability dates if associated host declines the booking' do
      patch "/api/v1/bookings/#{booking.id}", params: {
        status: 'declined',
        host_message: 'iDecline!!!'
      },
      headers: headers_host1
      profile1.reload
      expect(response.status).to eq 200
      expect(profile1.availability).to eq [1562803200000, 1562889600000, 1562976000000, 1563062400000, 1563148800000]
      expect(ActionMailer::Base.deliveries.count).to eq 1
    end

    it 'does not update status of certain booking even if action comes from associated host cause host_message is more than 200 characters' do
      patch "/api/v1/bookings/#{booking.id}", params: {
        status: 'accepted',
        host_message: 'accepted by host accepted by host accepted by host accepted by host accepted by host accepted by host accepted by host accepted by host accepted by host accepted by host accepted by host accepted by host'
      },
      headers: headers_host1
      expect(response.status).to eq 422
      expect(json_response['error']).to eq ['Host message is too long (maximum is 200 characters)']
      booking.reload
      expect(booking.status).to eq 'pending'
      expect(booking.host_message).to eq nil
    end

    it 'does not update status of certain booking if action comes from an unassociated host' do
      patch "/api/v1/bookings/#{booking.id}", params: {
        status: 'declined',
        host_message: 'declined by host'
      },
      headers: headers_host2
      expect(response.status).to eq 422
      expect(json_response['error']).to eq 'You cannot perform this action'
    end

    it 'does not update status of certain booking even if action comes from the user that requested it in the first place' do
      patch "/api/v1/bookings/#{booking.id}", params: {
        status: 'accepted',
        host_message: 'accepted by host'
      },
      headers: headers_user1
      expect(response.status).to eq 422
      expect(json_response['error']).to eq 'You cannot perform this action'
    end

    it 'does not update any booking if user is not authenticated' do
      patch "/api/v1/bookings/#{booking.id}", headers: headers_no_auth
      expect(response.status).to eq 401
      expect(json_response['errors']).to eq ['You need to sign in or sign up before continuing.']
    end

    it 'raises custom error in sad path where booking does not exist' do
      patch '/api/v1/bookings/2000000000', headers: headers_user1
      expect(response.status).to eq 404
      expect(json_response['error']).to eq ['We cannot update this booking because the user requested an account deletion! Please go back to your bookings page.']
    end
  end
end
