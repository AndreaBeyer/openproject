#-- encoding: UTF-8

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2021 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See docs/COPYRIGHT.rdoc for more details.
#++

require 'spec_helper'

describe Members::CreateService, type: :model do
  let(:user) { FactoryBot.build_stubbed(:user) }
  let(:contract_class) do
    double('contract_class', '<=': true)
  end
  let(:member_valid) { true }
  let(:instance) do
    described_class.new(user: user,
                        contract_class: contract_class)
  end
  let(:principal) { FactoryBot.build_stubbed(:user) }
  let(:roles) { [FactoryBot.build_stubbed(:role)] }
  let(:project) { FactoryBot.build_stubbed(:project) }
  let(:call_attributes) { { principal: principal, roles: roles, project: project } }
  let(:set_attributes_success) do
    true
  end
  let(:set_attributes_errors) do
    double('set_attributes_errors')
  end
  let(:set_attributes_result) do
    ServiceResult.new result: created_member,
                      success: set_attributes_success,
                      errors: set_attributes_errors
  end
  let!(:created_member) do
    member = FactoryBot.build_stubbed(:member,
                                      principal: principal,
                                      roles: roles,
                                      project: project)

    allow(Member)
      .to receive(:new)
      .and_return(member)

    allow(member)
      .to receive(:save)
      .and_return(member_valid)

    member
  end
  let!(:set_attributes_service) do
    service = double('set_attributes_service_instance')

    allow(Members::SetAttributesService)
      .to receive(:new)
      .with(user: user,
            model: created_member,
            contract_class: contract_class,
            contract_options: {})
      .and_return(service)

    allow(service)
      .to receive(:call)
      .and_return(set_attributes_result)
  end
  let!(:allow_notification_call) do
    allow(OpenProject::Notifications)
      .to receive(:send)
  end

  describe 'call' do
    subject { instance.call(call_attributes) }

    it 'is successful' do
      expect(subject.success?).to be_truthy
    end

    it 'returns the result of the SetAttributesService' do
      expect(subject)
        .to eql set_attributes_result
    end

    it 'persists the member' do
      expect(created_member)
        .to receive(:save)
        .and_return(member_valid)

      subject
    end

    it 'creates a member' do
      expect(subject.result)
        .to eql created_member
    end

    it 'sends a notification' do
      expect(OpenProject::Notifications)
        .to receive(:send)
        .with(OpenProject::Events::MEMBER_CREATED,
              member: created_member)

      subject
    end

    context 'if the SetAttributeService is unsuccessful' do
      let(:set_attributes_success) { false }

      it 'is unsuccessful' do
        expect(subject.success?).to be_falsey
      end

      it 'returns the result of the SetAttributesService' do
        expect(subject)
          .to eql set_attributes_result
      end

      it 'does not persist the changes' do
        expect(created_member)
          .to_not receive(:save)

        subject
      end

      it "exposes the contract's errors" do
        subject

        expect(subject.errors).to eql set_attributes_errors
      end

      it 'sends no notification' do
        expect(OpenProject::Notifications)
          .not_to receive(:send)

        subject
      end
    end

    context 'when the member is invalid' do
      let(:member_valid) { false }

      it 'is unsuccessful' do
        expect(subject.success?).to be_falsey
      end

      it "exposes the member's errors" do
        subject

        expect(subject.errors).to eql created_member.errors
      end

      it 'sends no notification' do
        expect(OpenProject::Notifications)
          .not_to receive(:send)

        subject
      end
    end
  end
end