def targetBranch = env.getEnvironment().get('CHANGE_TARGET', env.BRANCH_NAME)

library "kubic-jenkins-library@${targetBranch}"

error "Bail Early for testing the HouseKeeping job"
coreKubicProjectCi()
