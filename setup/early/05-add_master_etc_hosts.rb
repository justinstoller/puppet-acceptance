test_name "Add Master entry to /etc/hosts"

step "Get ip address of Master #{master}"
ip = ''
on master, "ip a|awk '/g/{print$2}' | cut -d/ -f1 | head -1" do |stdout, stderr, exit_code|
  ip = stdout.chomp
end

step "Update /etc/host on #{master}"
# Preserve the mode the easy way...
on master, "echo \"#{ip} #{master}\" >> /etc/hosts"
