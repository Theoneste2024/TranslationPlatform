from django.core.management.base import BaseCommand, CommandError

from users.models import Permission, Role, User


class Command(BaseCommand):
    help = 'Grant or revoke a named permission for a role or an individual user.'

    def add_arguments(self, parser):
        parser.add_argument('action', choices=['grant', 'revoke'])
        parser.add_argument('codename')
        target = parser.add_mutually_exclusive_group(required=True)
        target.add_argument('--role')
        target.add_argument('--email')

    def handle(self, *args, **options):
        try:
            if options['action'] == 'grant':
                permission, _ = Permission.objects.get_or_create(
                    codename=options['codename'],
                    defaults={'name': options['codename']},
                )
                permission.grant_to_superusers()
            else:
                permission = Permission.objects.get(codename=options['codename'])
        except Permission.DoesNotExist as error:
            raise CommandError('No permission exists with that codename.') from error

        if options['role']:
            try:
                subject = Role.objects.get(name=options['role'])
            except Role.DoesNotExist as error:
                raise CommandError('No role exists with that name.') from error
            relation = permission.roles
        else:
            try:
                subject = User.objects.get(email=options['email'].strip().lower())
            except User.DoesNotExist as error:
                raise CommandError('No user exists with that email address.') from error
            relation = permission.users

        if options['action'] == 'grant':
            relation.add(subject)
        else:
            relation.remove(subject)
        result = 'Granted' if options['action'] == 'grant' else 'Revoked'
        self.stdout.write(
            self.style.SUCCESS(
                f'{result} {permission.codename} for {subject}.'
            )
        )
