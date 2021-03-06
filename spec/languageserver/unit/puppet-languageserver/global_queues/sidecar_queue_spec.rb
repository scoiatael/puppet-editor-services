require 'spec_helper'
require 'puppet-languageserver/session_state/document_store'

describe 'PuppetLanguageServer::GlobalQueues::SidecarQueueJob' do
  let(:action) { 'action' }
  let(:additional_args) { [] }
  let(:handle_errors) { false }
  let(:connection_id) { 'id1234' }

  let(:subject) { PuppetLanguageServer::GlobalQueues::SidecarQueueJob.new(action, additional_args, handle_errors, connection_id) }

  it 'is a SingleInstanceQueueJob' do
    expect(subject).is_a?(PuppetLanguageServer::GlobalQueues::SingleInstanceQueueJob)
  end

  it 'uses the action and connection_id for the key' do
    expect(subject.key).to eq("#{action}-#{connection_id}")
  end
end

describe 'PuppetLanguageServer::GlobalQueues::SidecarQueue' do
  let(:subject) { PuppetLanguageServer::GlobalQueues::SidecarQueue.new }

  it 'is a SingleInstanceQueue' do
    expect(subject).is_a?(PuppetLanguageServer::GlobalQueues::SingleInstanceQueue)
  end

  it 'has a job_class of SidecarQueueJob' do
    expect(subject.job_class).is_a?(PuppetLanguageServer::GlobalQueues::SingleInstanceQueueJob)
  end

  describe '#execute' do
    let(:mock_connection) { Object.new }
    let(:connection_id) { 'mock_conn_id' }
    let(:cache) { PuppetLanguageServer::SessionState::ObjectCache.new }
    let(:session_state) { PuppetLanguageServer::ClientSessionState.new(nil, :object_cache => cache, :connection_id => connection_id) }

    before(:each) do
      # Mock a connection and session state
      allow(subject).to receive(:connection_from_connection_id).with(connection_id).and_return(mock_connection)
      allow(subject).to receive(:sidecar_args_from_connection).with(mock_connection).and_return([])
      allow(subject).to receive(:session_state_from_connection).with(mock_connection).and_return(session_state)
    end

    class SuccessStatus
      def exitstatus
        0
      end
    end

    context 'default_aggregate action' do
      let(:action) { 'default_aggregate' }

      it 'should deserialize the json, import into the cache' do
        fixture = PuppetLanguageServer::Sidecar::Protocol::AggregateMetadata.new
        fixture.append!(random_sidecar_puppet_class)
        fixture.append!(random_sidecar_puppet_function)
        fixture.append!(random_sidecar_puppet_type)
        sidecar_response = [fixture.to_json, 'stderr', SuccessStatus.new]

        expect(subject).to receive(:run_sidecar).and_return(sidecar_response)

        subject.execute(action, [], false, connection_id)
        expect(cache.object_by_name(:class, fixture.classes[0].key)).to_not be_nil
        expect(cache.object_by_name(:function, fixture.functions[0].key)).to_not be_nil
        expect(cache.object_by_name(:type, fixture.types[0].key)).to_not be_nil
      end
    end

    context 'default_classes action' do
      let(:action) { 'default_classes' }

      it 'should deserialize the json, import into the cache' do
        fixture = PuppetLanguageServer::Sidecar::Protocol::PuppetClassList.new
        fixture << random_sidecar_puppet_class
        sidecar_response = [fixture.to_json, 'stderr', SuccessStatus.new]

        expect(subject).to receive(:run_sidecar).and_return(sidecar_response)

        subject.execute(action, [], false, connection_id)
        expect(cache.object_by_name(:class, fixture[0].key)).to_not be nil
      end
    end

    context 'default_functions action' do
      let(:action) { 'default_functions' }

      it 'should deserialize the json, import into the cache' do
        fixture = PuppetLanguageServer::Sidecar::Protocol::PuppetFunctionList.new
        fixture << random_sidecar_puppet_function
        sidecar_response = [fixture.to_json, 'stderr', SuccessStatus.new]

        expect(subject).to receive(:run_sidecar).and_return(sidecar_response)

        subject.execute(action, [], false, connection_id)
        expect(cache.object_by_name(:function, fixture[0].key)).to_not be nil
      end
    end

    context 'default_types action' do
      let(:action) { 'default_types' }

      it 'should deserialize the json, import into the cache' do
        fixture = PuppetLanguageServer::Sidecar::Protocol::PuppetTypeList.new
        fixture << random_sidecar_puppet_type
        sidecar_response = [fixture.to_json, 'stderr', SuccessStatus.new]

        expect(subject).to receive(:run_sidecar).and_return(sidecar_response)

        subject.execute(action, [], false, connection_id)
        expect(cache.object_by_name(:type, fixture[0].key)).to_not be nil
      end
    end
  end
end
