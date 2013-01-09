require 'spec_helper'

module PuppetAcceptance
  module Hosts
    describe Abstraction do
      let :config do
        MockConfig.new({}, {'name' => {'platform' => @platform}}, @pe)
      end

      let(:options) { @options || Hash.new                  }
      let(:host)    { Abstraction.create 'name', options, config   }

      before { SshConnection.stub( :connect ).and_return( double.as_null_object ) }

      it 'creates a windows host given a windows config' do
        @platform = 'windows'
        expect( host ).
          to be_a_kind_of PuppetAcceptance::Hosts::Windows::Host
      end

      it 'defaults to a unix host' do
        expect( host ).to be_a_kind_of PuppetAcceptance::Hosts::Unix::Host
      end
    end
  end
end
