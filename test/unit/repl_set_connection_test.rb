require './test/test_helper'
include Mongo

class ReplSetConnectionTest < Test::Unit::TestCase
  context "Initialization: " do
    setup do
      def new_mock_socket(host='localhost', port=27017)
        socket = Object.new
        socket.stubs(:setsockopt).with(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)
        socket.stubs(:close)
        socket
      end

      def new_mock_db
        db = Object.new
      end
    end

    context "connecting to a replica set" do
      setup do
        TCPSocket.stubs(:new).returns(new_mock_socket('localhost', 27017))
        @conn = ReplSetConnection.new(['localhost', 27017], :connect => false, :read_secondary => true)

        admin_db = new_mock_db
        @hosts = ['localhost:27018', 'localhost:27019', 'localhost:27020']

        admin_db.stubs(:command).returns({'ok' => 1, 'ismaster' => 1, 'hosts' => @hosts}).
          then.returns({'ok' => 1, 'ismaster' => 0, 'hosts' => @hosts, 'secondary' => 1}).
          then.returns({'ok' => 1, 'ismaster' => 0, 'hosts' => @hosts, 'secondary' => 1}).
          then.returns({'ok' => 1, 'ismaster' => 0, 'arbiterOnly' => 1})

        @conn.stubs(:[]).with('admin').returns(admin_db)
        @conn.connect
      end

      should "store the hosts returned from the ismaster command" do
        assert_equal 'localhost', @conn.primary_pool.host
        assert_equal 27017, @conn.primary_pool.port

        assert_equal 'localhost', @conn.secondary_pools[0].host
        assert_equal 27018, @conn.secondary_pools[0].port

        assert_equal 'localhost', @conn.secondary_pools[1].host
        assert_equal 27019, @conn.secondary_pools[1].port

        assert_equal 2, @conn.secondary_pools.length
      end
    end

    context "connecting to a replica set and providing seed nodes" do
      setup do
        TCPSocket.stubs(:new).returns(new_mock_socket)
        @conn = ReplSetConnection.new(['localhost', 27017], ['localhost', 27019], :connect => false)

        admin_db = new_mock_db
        @hosts = ['localhost:27017', 'localhost:27018', 'localhost:27019']
        admin_db.stubs(:command).returns({'ok' => 1, 'ismaster' => 1, 'hosts' => @hosts})
        @conn.stubs(:[]).with('admin').returns(admin_db)
        @conn.connect
      end
    end

    context "initializing with a mongodb uri" do

      should "parse a uri specifying multiple nodes" do
        @conn = Connection.from_uri("mongodb://localhost:27017,mydb.com:27018", :connect => false)
        assert_equal ['localhost', 27017], @conn.nodes[0]
        assert_equal ['mydb.com', 27018], @conn.nodes[1]
      end

      should "parse a uri specifying multiple nodes with auth" do
        @conn = Connection.from_uri("mongodb://kyle:s3cr3t@localhost:27017/app,mickey:m0u5e@mydb.com:27018/dsny", :connect => false)
        assert_equal ['localhost', 27017], @conn.nodes[0]
        assert_equal ['mydb.com', 27018], @conn.nodes[1]
        auth_hash = {'username' => 'kyle', 'password' => 's3cr3t', 'db_name' => 'app'}
        assert_equal auth_hash, @conn.auths[0]
        auth_hash = {'username' => 'mickey', 'password' => 'm0u5e', 'db_name' => 'dsny'}
        assert_equal auth_hash, @conn.auths[1]
      end
    end
  end
end
