#!/bin/bash

QUESTIONS_PATH="/root/week2question"
OUTPUT_FILE="/tmp/${NAME}_week2result.txt"
PDF_FILE="/tmp/${NAME}_week2result.pdf"

# Function to install required packages
install_requirements() {
    if ! command -v sshpass &> /dev/null; then
        echo -e "\nINFO: The sshpass RPM is required to verify your exam results but is not currently installed. Attempting installation via the yum repository.\n"
        if ! yum install sshpass -y -q > /dev/null 2>&1; then
            echo -e "\nERROR: Failed to install sshpass RPM. Please check your repository configuration and try again.\n"
            exit 1
        fi
    fi

    if ! command -v enscript &> /dev/null || ! command -v ps2pdf &> /dev/null; then
        echo -e "\nINFO: The enscript and ps2pdf utilities are required to convert the result to PDF. Attempting installation via the yum repository.\n"
        if ! yum install enscript ghostscript -y -q > /dev/null 2>&1; then
            echo -e "\nERROR: Failed to install enscript or ghostscript. Please check your repository configuration and try again.\n"
            exit 1
        fi
    fi
}

# Function to create the question paper
create_environment() {
    echo "INFO: Creating the question paper..."
    cat <<EOF > $QUESTIONS_PATH
1. Configure 'bond0' on 'servera' in active-backup mode using the current IP address.
2. Create a repository for your 'servera' using below link:
   - file:///dvd/rhel92/BaseOS/
   - file:///dvd/rhel92/AppStream/
3. Create a repository for your 'serverb' using below link:
   - http://servera.example.com/rhel94/BaseOS/
   - http://servera.example.com/rhel94/AppStream/
4. Install 'bind-chroot' without dependencies on 'servera'.
5. Import the GPG key on both 'servera' and 'serverb'.
6. Find all files related to the 'sendmail' package and redirect the output to '/exam/listfile' on 'servera'.
   Do not install the 'sendmail' package.
7. Install the 'httpd' application using 'yum' on 'servera'.
   Start and enable the 'httpd' service.
   Capture the PID, COMM, CPU, and memory usage of the running web service, and redirect the output to '/exam/apache' on 'servera'.
8. Set up password-less SSH authentication from 'root@servera' to 'root@serverb'.
9. Create alias names for 'servera' and 'serverb' as 'tuxa' and 'tuxb', respectively.
10. Install and find the 'vsftpd' configuration file and redirect the output to '/exam/vsftpd' on 'servera'.
11. Find the RPM package that owns the '/etc/passwd' file and redirect the output to '/exam/rpm' on 'servera'.
12. Validate that 'serverb' is patched to RHEL 9.4.
13. Initiate a system boot with the new kernel.
14. Create a cron job on 'servera' that generates a disk usage report for the '/home' directory 
    and saves it to '/exam/dureport' every Sunday at 3 AM.
EOF
    echo "INFO: Question paper created at $QUESTIONS_PATH."
}

# Function to delete network connections
delete_network_connections() {
    nmcli connection show | grep -v "NAME" | awk '{print $1}' | xargs -I {} nmcli connection delete {} &>/dev/null
}

# Function to get the MAC address
get_mac_address() {
    ip link show | grep -m 1 ether | awk '{print $2}'
}

# Function to validate the environment and save output to a text file
validate_environment() {
    echo -n "Please enter your name: "
    read NAME
    NAME=$(echo $NAME | tr ' ' '_' ) # Replace spaces with underscores for filenames

    OUTPUT_FILE="/tmp/${NAME}_week2result.txt"
    PDF_FILE="/tmp/${NAME}_week2result.pdf"

    MACADDR=$(get_mac_address)
    DATEANDTIME=$(date)

    echo -e "\nHello $NAME" | tee $OUTPUT_FILE
    echo -e "MAC Address   : $MACADDR" | tee -a $OUTPUT_FILE
    echo -e "Date and Time : $DATEANDTIME" | tee -a $OUTPUT_FILE
    echo | tee -a $OUTPUT_FILE

    # Validations

    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validating bond0 active-backup configuration" | tee -a $OUTPUT_FILE
    if grep -q 'Bonding Mode: fault-tolerance (active-backup)' /proc/net/bonding/bond0 2>/dev/null; then
        print_result "bond0 active-backup configuration:" 0 | tee -a $OUTPUT_FILE
    else
        print_result "bond0 active-backup configuration:" 1 | tee -a $OUTPUT_FILE
    fi

    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validate the repository on servera and serverb with a dry run" | tee -a $OUTPUT_FILE

    # Dry run test function
    dry_run_test() {
        local package_name="$1"
        yum install "$package_name" --setopt=tsflags=test -yq > /dev/null 2>&1
        return $?
    }  

    # Dry run test for servera
    if dry_run_test "zsh"; then
        print_result "servera's repos is correct" 0 | tee -a $OUTPUT_FILE
    else
        print_result "servera's repos is incorrect" 1 | tee -a $OUTPUT_FILE
    fi

    # Dry run test for serverb via SSH
    if sshpass -p 'redhat' ssh -o StrictHostKeyChecking=no root@serverb "yum install zsh --setopt=tsflags=test -yq > /dev/null 2>&1"; then
        print_result "serverb's repos is correct" 0 | tee -a $OUTPUT_FILE
    else
        print_result "serverb's repos is incorrect" 1 | tee -a $OUTPUT_FILE
    fi
      
    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validating bind-chroot installation on servera" | tee -a $OUTPUT_FILE
    if rpm -q bind-chroot &>/dev/null; then
        print_result "bind-chroot installed without dependencies on servera:" 0 | tee -a $OUTPUT_FILE
    else
        print_result "bind-chroot installed without dependencies on servera:" 1 | tee -a $OUTPUT_FILE
    fi

    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validating GPG key import on servera and serverb" | tee -a $OUTPUT_FILE
    if rpm -qa gpg-pubkey | grep -q 'gpg-pubkey'; then
        print_result "GPG key imported on servera:" 0 | tee -a $OUTPUT_FILE
    else
        print_result "GPG key imported on servera:" 1 | tee -a $OUTPUT_FILE
    fi

#    echo | tee -a $OUTPUT_FILE
#    echo "INFO: Validating GPG key import on serverb" | tee -a $OUTPUT_FILE
    if sshpass -p 'redhat' ssh -o StrictHostKeyChecking=no root@serverb 'rpm -qa gpg-pubkey | grep -q "gpg-pubkey"' 2>/dev/null; then
        print_result "GPG key imported on serverb:" 0 | tee -a $OUTPUT_FILE
    else
        print_result "GPG key imported on serverb:" 1 | tee -a $OUTPUT_FILE
    fi

    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validating sendmail package file list" | tee -a $OUTPUT_FILE
    SENDMAIL_FILES="/exam/listfile"
    EXPECTED_FILES=(
        "/etc/mail"
        "/etc/mail/Makefile"
        "/etc/mail/access"
        "/etc/mail/access.db"
        "/etc/mail/aliasesdb-stamp"
        "/etc/mail/domaintable"
        "/etc/mail/domaintable.db"
        "/etc/mail/helpfile"
        "/etc/mail/local-host-names"
        "/etc/mail/mailertable"
        "/etc/mail/mailertable.db"
        "/etc/mail/make"
        "/etc/mail/sendmail.cf"
        "/etc/mail/sendmail.mc"
        "/etc/mail/submit.cf"
        "/etc/mail/submit.mc"
        "/etc/mail/trusted-users"
        "/etc/mail/virtusertable"
        "/etc/mail/virtusertable.db"
        "/etc/pam.d/smtp"
        "/etc/pam.d/smtp.sendmail"
        "/etc/sasl2/Sendmail.conf"
        "/etc/smrsh"
        "/etc/sysconfig/sendmail"
        "/usr/bin/hoststat"
        "/usr/bin/mailq"
        "/usr/bin/mailq.sendmail"
        "/usr/bin/makemap"
        "/usr/bin/newaliases"
        "/usr/bin/newaliases.sendmail"
        "/usr/bin/purgestat"
        "/usr/bin/rmail"
        "/usr/bin/rmail.sendmail"
        "/usr/lib/.build-id"
        "/usr/lib/.build-id/0d"
        "/usr/lib/.build-id/0d/ca8f66896986a62f6323518a6fad895c186a45"
        "/usr/lib/.build-id/45"
        "/usr/lib/.build-id/45/570ef63835509e0e56f1dc4438dba0893842c4"
        "/usr/lib/.build-id/46"
        "/usr/lib/.build-id/46/3d2ac5fad4dd4a3a83ed23fac2e85a5e0a63cf"
        "/usr/lib/.build-id/4d"
        "/usr/lib/.build-id/4d/b47784389b9c5196536dfa605e0c91dc55b6e8"
        "/usr/lib/.build-id/a4"
        "/usr/lib/.build-id/a4/a082df82bf5f61981b4066e6e7351f3c42ec19"
        "/usr/lib/.build-id/e3"
        "/usr/lib/.build-id/e3/5f1eeb73f911dcb7b7ee49eb1db3ddfe1519ca"
        "/usr/lib/.build-id/ec"
        "/usr/lib/.build-id/ec/8f65c45c3b8b8c5441873f31fa2261afda854d"
        "/usr/lib/NetworkManager"
        "/usr/lib/NetworkManager/dispatcher.d"
        "/usr/lib/NetworkManager/dispatcher.d/10-sendmail"
        "/usr/lib/sendmail"
        "/usr/lib/sendmail.sendmail"
        "/usr/lib/systemd/system/sendmail.service"
        "/usr/lib/systemd/system/sm-client.service"
        "/usr/sbin/editmap"
        "/usr/sbin/editmap.sendmail"
        "/usr/sbin/mailstats"
        "/usr/sbin/makemap"
        "/usr/sbin/makemap.sendmail"
        "/usr/sbin/praliases"
        "/usr/sbin/sendmail"
        "/usr/sbin/sendmail.sendmail"
        "/usr/sbin/smrsh"
        "/usr/share/doc/sendmail"
        "/usr/share/doc/sendmail/FAQ"
        "/usr/share/doc/sendmail/KNOWNBUGS"
        "/usr/share/doc/sendmail/LICENSE"
        "/usr/share/doc/sendmail/README"
        "/usr/share/doc/sendmail/RELEASE_NOTES.gz"
        "/usr/share/man/man1/mailq.1.gz"
        "/usr/share/man/man1/mailq.sendmail.1.gz"
        "/usr/share/man/man1/newaliases.1.gz"
        "/usr/share/man/man1/newaliases.sendmail.1.gz"
        "/usr/share/man/man5/aliases.5.gz"
        "/usr/share/man/man5/aliases.sendmail.5.gz"
        "/usr/share/man/man8/editmap.8.gz"
        "/usr/share/man/man8/editmap.sendmail.8.gz"
        "/usr/share/man/man8/hoststat.8.gz"
        "/usr/share/man/man8/mailstats.8.gz"
        "/usr/share/man/man8/makemap.8.gz"
        "/usr/share/man/man8/makemap.sendmail.8.gz"
        "/usr/share/man/man8/praliases.8.gz"
        "/usr/share/man/man8/purgestat.8.gz"
        "/usr/share/man/man8/rmail.8.gz"
        "/usr/share/man/man8/rmail.sendmail.8.gz"
        "/usr/share/man/man8/sendmail.8.gz"
        "/usr/share/man/man8/sendmail.sendmail.8.gz"
        "/usr/share/man/man8/smrsh.8.gz"
        "/var/log/mail"
        "/var/log/mail/statistics"
        "/var/spool/clientmqueue"
        "/var/spool/clientmqueue/sm-client.st"
        "/var/spool/mqueue"
    )

    if [ -f "$SENDMAIL_FILES" ]; then
        MATCH=0
        for FILE in "${EXPECTED_FILES[@]}"; do
            if grep -q "$FILE" "$SENDMAIL_FILES"; then
                MATCH=$((MATCH + 1))
            fi
        done
        if [ "$MATCH" -eq "${#EXPECTED_FILES[@]}" ]; then
            print_result "/exam/listfile contains sendmail package files" 0 | tee -a $OUTPUT_FILE
        else
            print_result "/exam/listfile contains sendmail package files" 1 | tee -a $OUTPUT_FILE
        fi
    else
        print_result "/exam/listfile contains sendmail package files" 1 | tee -a $OUTPUT_FILE
    fi

    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validating httpd installation and service" | tee -a $OUTPUT_FILE
#   if rpm -q httpd-2.4.57-11.el9_2.4.x86_64 &>/dev/null; then
    if rpm -q httpd-2.4.57-8.el9.x86_64 &>/dev/null; then
        print_result "Web package installed" 0 | tee -a $OUTPUT_FILE
    else
        print_result "Web package missing" 1 | tee -a $OUTPUT_FILE
    fi

    if systemctl is-enabled httpd &>/dev/null; then
        print_result "Web service enabled" 0 | tee -a $OUTPUT_FILE
    else
        print_result "Web service disabled" 1 | tee -a $OUTPUT_FILE
    fi

    if systemctl is-active httpd &>/dev/null; then
        print_result "Web service running" 0 | tee -a $OUTPUT_FILE
    else
        print_result "Web service stopped" 1 | tee -a $OUTPUT_FILE
    fi

    if [ -f /exam/apache ] && [ $(wc -l < /exam/apache) -eq 6 ] && grep -q "%CPU" /exam/apache; then
        cpu_column=$(awk '{print $5}' /exam/apache | tail -n +2) # %CPU values
        cmd_column=$(awk '{print $3}' /exam/apache | tail -n +2)  # CMD values

        if echo "$cpu_column" | sort -nr | cmp -s - <(echo "$cpu_column"); then
            print_result "Web process info logged and sorted in /exam/apache" 0 | tee -a $OUTPUT_FILE
        else
            print_result "Web process info logged and sorted in /exam/apache" 1 | tee -a $OUTPUT_FILE
        fi
    else
        print_result "Incorrect info in /exam/apache" 1 | tee -a $OUTPUT_FILE
    fi

    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validating SSH authentication and hostname aliases" | tee -a $OUTPUT_FILE

    # Validate password-less SSH authentication from servera to serverb
    if ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no root@serverb "echo SSH Connection Successful" > /dev/null 2>&1; then
        print_result "SSH authentication from servera to serverb is successful." 0 | tee -a $OUTPUT_FILE
    else
        print_result "SSH authentication from servera to serverb failed." 1 | tee -a $OUTPUT_FILE
    fi

    # Validate alias 'tuxa' on servera by pinging 'tuxb'
    if ping -c 1 -w 1 tuxb > /dev/null 2>&1; then
        print_result "Alias 'tuxa' resolves to 'tuxb' and is reachable." 0 | tee -a $OUTPUT_FILE
    else
        print_result "Alias 'tuxa' does not resolve or is unreachable." 1 | tee -a $OUTPUT_FILE
    fi

    # Validate alias 'tuxb' on serverb via SSH by pinging 'tuxa'
    if ssh -o StrictHostKeyChecking=no root@serverb "ping -c 1 -w 1 tuxa > /dev/null 2>&1"; then
        print_result "Alias 'tuxb' resolves to 'tuxa' and is reachable." 0 | tee -a $OUTPUT_FILE
    else
        print_result "Alias 'tuxb' does not resolve or is unreachable." 1 | tee -a $OUTPUT_FILE
    fi

#    echo | tee -a $OUTPUT_FILE
#    echo "INFO: Validating high memory usage processes" | tee -a $OUTPUT_FILE
#    if [ -f /exam/highmem ] && [ $(wc -l < /exam/highmem) -eq 6 ] && grep -q "%MEM" /exam/highmem; then
#       mem_column=$(awk '{print $5}' /exam/highmem | tail -n +2) # %MEM values
#       cmd_column=$(awk '{print $3}' /exam/highmem | tail -n +2)  # CMD values

#       if echo "$cmd_column" | grep -q -v "^perl$"; then
#          print_result "Incorrect info in /exam/highmem" 1 | tee -a $OUTPUT_FILE
#       else
#          if echo "$mem_column" | sort -nr | cmp -s - <(echo "$mem_column"); then
#             print_result "Correct info in /exam/highmem" 0 | tee -a $OUTPUT_FILE
#          else
#            print_result "Incorrect info in /exam/highmem" 1 | tee -a $OUTPUT_FILE
#          fi
#      fi
#    else
#       print_result "High memory check failed" 1 | tee -a $OUTPUT_FILE
#    fi

     echo | tee -a $OUTPUT_FILE
     echo "INFO: Validating vsftpd installation and configuration file" | tee -a $OUTPUT_FILE

    EXPECTED_VSFTPD_FILES=(
        "/etc/logrotate.d/vsftpd"
        "/etc/pam.d/vsftpd"
        "/etc/vsftpd/ftpusers"
        "/etc/vsftpd/user_list"
        "/etc/vsftpd/vsftpd.conf"
    )  

    if [ -f /exam/vsftpd ]; then
       VALID=1
       for FILE in "${EXPECTED_VSFTPD_FILES[@]}"; do
           if ! grep -Fxq "$FILE" /exam/vsftpd; then
              VALID=0
              echo "Missing file: $FILE" | tee -a $OUTPUT_FILE
              break
           fi
       done

       if [ "$VALID" -eq 1 ]; then
          print_result "Configuration check in /exam/vsftpd" 0 | tee -a $OUTPUT_FILE
       else
          print_result "Configuration check in /exam/vsftpd" 1 | tee -a $OUTPUT_FILE
       fi
    else
       print_result "Configuration check in /exam/vsftpd" 1 | tee -a $OUTPUT_FILE
    fi

    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validating the RPM name owning /etc/passwd" | tee -a $OUTPUT_FILE
    EXPECTED_RPM_PACKAGE="setup-2.13.7-9.el9.noarch"

    if [ -f /exam/rpm ]; then
        if grep -q "$EXPECTED_RPM_PACKAGE" /exam/rpm; then
            print_result "RPM name validation successful in /exam/rpm" 0 | tee -a $OUTPUT_FILE
        else
            print_result "RPM name validation failed in /exam/rpm" 1 | tee -a $OUTPUT_FILE
        fi
    else
        print_result "RPM name validation failed in /exam/rpm - file not found" 1 | tee -a $OUTPUT_FILE
    fi

    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validating OS version on serverb" | tee -a $OUTPUT_FILE
    EXPECTED_VERSION="Red Hat Enterprise Linux release 9.4"
    if sshpass -p 'redhat' ssh root@serverb "grep -q '$EXPECTED_VERSION' /etc/redhat-release"; then
        print_result "Serverb running expected RHEL Version" 0 | tee -a $OUTPUT_FILE
    else
        print_result "Serverb not running expected RHEL Version" 1 | tee -a $OUTPUT_FILE
    fi

    
    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validating kernel version on serverb" | tee -a $OUTPUT_FILE
    expected_kernel_version="5.14.0-427.13.1.el9_4.x86_64"
    current_kernel_version=$(sshpass -p 'redhat' ssh -o StrictHostKeyChecking=no root@serverb "uname -r | tr -d '[:space:]'")
    # Debugging output to show the exact values being compared
    echo "Expected kernel version: '$expected_kernel_version'" | tee -a $OUTPUT_FILE
    echo "Current kernel version:  '$current_kernel_version'" | tee -a $OUTPUT_FILE

    if [ "$current_kernel_version" == "$expected_kernel_version" ]; then
       print_result "Kernel version is correct" 0 | tee -a $OUTPUT_FILE
    else
       print_result "Incorrect kernel version" 1 | tee -a $OUTPUT_FILE
    fi


    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validating crond service status, enabled state, and cron job" | tee -a $OUTPUT_FILE

    # Check if the crond service is active (running)
    if systemctl is-active --quiet crond; then
        print_result "Service 'crond' is active" 0 | tee -a $OUTPUT_FILE
    else
        print_result "Service 'crond' is not active" 1 | tee -a $OUTPUT_FILE
    fi

    # Check if the crond service is enabled (set to start at boot)
    if systemctl is-enabled --quiet crond; then
        print_result "Service 'crond' is enabled at startup." 0 | tee -a $OUTPUT_FILE
    else
        print_result "Service 'crond' is disabled at startup." 1 | tee -a $OUTPUT_FILE
    fi

    # Validate the specific cron job creation
    echo | tee -a $OUTPUT_FILE
    echo "INFO: Validating cron job creation" | tee -a $OUTPUT_FILE
    if crontab -l 2>/dev/null | grep -q "0 3 \* \* 0 du -sh /home > /exam/dureport"; then
        print_result "Cron job validation succeeded" 0 | tee -a $OUTPUT_FILE
    else
        print_result "Cron job validation failed" 1 | tee -a $OUTPUT_FILE
    fi

    # Convert the text output to PDF
    enscript -B -q -p - "$OUTPUT_FILE" | ps2pdf - "$PDF_FILE"
    rm -f $OUTPUT_FILE

    echo | tee -a $OUTPUT_FILE
    echo "INFO: Result saved as PDF: $PDF_FILE"
}

# Function to cleanup the exam environment
cleanup_environment() {
    echo "INFO: Cleaning up the exam environment..."
    delete_repo_files
    rm -f /exam/listfile /exam/apache /exam/vsftpd /exam/rpm /exam/dureport
    echo "INFO: Exam environment has been cleaned up."
}

# Function to display results with proper alignment
print_result() {
    local label="$1"
    local status="$2"
#    local max_length=65
    local max_length=73
    local padding=$(printf '%*s' $((max_length - ${#label})) '')

    if [ "$status" -eq 0 ]; then
        echo -e "${label}${padding}PASS"
    else
        echo -e "${label}${padding}FAIL"
    fi
}

# Main script logic
case $1 in
    create)
        delete_network_connections
        install_requirements
        create_environment
        ;;
    cleanup)
        cleanup_environment
        ;;
    validate)
        validate_environment
        ;;
    *)
        echo "Usage: $0 {create|cleanup|validate}"
        exit 1
        ;;
esac

