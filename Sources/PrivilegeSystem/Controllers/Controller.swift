import PrivilegeModule

protocol SystemController: Controller where E == PrivilegeSystem.Errcase {}
